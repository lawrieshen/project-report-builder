"""Run synthetic acceptance cases through the authenticated API; never bypass its ledger."""
import argparse
from datetime import UTC, datetime
import getpass
import hashlib
import http.client
import json
from pathlib import Path
from time import monotonic
from uuid import uuid4, uuid5, UUID

from prb_ai.contracts import Request, Response, parse_json

ROOT = Path(__file__).resolve().parents[1]
HOST = 'ic1fsr0eg6.execute-api.ap-southeast-2.amazonaws.com'


def cases():
    return json.loads((ROOT / 'evaluation/cases.json').read_text())


def make_request(case: dict, run_id: UUID) -> Request:
    fixture = ROOT.parent / 'backend/contracts/ai-compose/v1/request.json'
    data = json.loads(fixture.read_text())
    data['requestID'] = str(uuid5(run_id, case['id']))
    data['goal']['language'] = case['language']
    data['goal']['purpose'] = case['purpose']
    data['messages'] = [{'role': 'user', 'text': case['notes']}]
    return parse_json(Request, json.dumps(data))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true', help='Make up to ten charged API requests')
    parser.add_argument('--results', type=Path, default=ROOT / 'evaluation/results.json')
    args = parser.parse_args()
    existing = json.loads(args.results.read_text()) if args.results.exists() else None
    run_id = UUID(existing['runID']) if existing else uuid4()
    requests = [(case, make_request(case, run_id)) for case in cases()]
    fingerprint = hashlib.sha256(json.dumps([
        {'case': case, 'request': request.model_dump(mode='json', by_alias=True)}
        for case, request in requests
    ], sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    if existing and existing.get('requestFingerprint') != fingerprint:
        raise SystemExit('Cases or request fixtures changed. Preserve these results and choose a new --results file.')
    if not args.execute:
        print(f'Validated {len(requests)} synthetic requests; no network calls. Add --execute only after deployment gates pass.')
        return
    results = existing or {'runID': str(run_id), 'requestFingerprint': fingerprint, 'cases': {}}
    # Persist IDs before dispatch so an interrupted run never generates replacement IDs.
    args.results.parent.mkdir(parents=True, exist_ok=True)
    def save():
        temporary = args.results.with_suffix('.tmp')
        temporary.write_text(json.dumps(results, indent=2, ensure_ascii=False))
        temporary.replace(args.results)
    save()
    token = getpass.getpass('Cognito access token (hidden; never saved): ')
    if not token or any(char.isspace() for char in token):
        raise SystemExit('A nonempty access token without whitespace is required')
    for case, request in requests:
        previous = results['cases'].get(case['id'])
        if previous and previous.get('status') == 200:
            continue
        body = request.model_dump_json(by_alias=True)
        record = {'requestID': request.request_id, 'startedAt': datetime.now(UTC).isoformat(),
                  'review': {item: 'pending' for item in case['review']},
                  'usageReview': 'pending: inspect matching audit requestID', 'semanticReview': 'pending'}
        results['cases'][case['id']] = record
        save()
        started = monotonic()
        connection = http.client.HTTPSConnection(HOST, timeout=35)
        try:
            connection.request('POST', '/ai/compose', body=body.encode(), headers={
                'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
            reply = connection.getresponse()
            data = reply.read(160_001)
            record['status'] = reply.status
            record['latencyMs'] = round((monotonic() - started) * 1000)
            if len(data) > 160_000:
                raise ValueError('Oversized response')
            if reply.status == 200:
                result = parse_json(Response, data)
                if (result.request_id != request.request_id or result.base_draft_version != request.base_draft_version
                    or result.candidate_version != request.candidate_version or result.goal_id != request.goal.id
                    or result.goal_revision != request.goal.revision):
                    raise ValueError('Response identity mismatch')
                result.proposal.validate_against(request)
                record['response'] = result.model_dump(mode='json', by_alias=True)
                record['contractReview'] = 'passed'
            else:
                record['contractReview'] = 'not evaluated'
                # Error bodies are not printed or persisted; they could contain infrastructure details.
                save()
                print(f"Stopped at {case['id']}: HTTP {reply.status}. Existing request IDs remain reusable.")
                raise SystemExit(1)
        except Exception:
            record['status'] = 'unknown'
            record['contractReview'] = 'failed or transport outcome unknown'
            save()
            print(f"Stopped at {case['id']}; inspect the result and audit metadata before retrying.")
            raise SystemExit(1)
        finally:
            connection.close()
        save()
    print('Responses recorded. Semantic, usage, latency and end-to-end reviews are still required.')


if __name__ == '__main__':
    main()
