"""Validate published examples and transport constraints independently of Java."""
import copy
import json
import pathlib
import unittest

from jsonschema import Draft202012Validator, FormatChecker

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONTRACT = json.loads((ROOT / 'contracts/openapi.json').read_text())
EXAMPLE = json.loads((ROOT / 'contracts/create-report.json').read_text())
SCHEMA = {'$ref': '#/components/schemas/SaveRequest', 'components': CONTRACT['components']}


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.validator = Draft202012Validator(SCHEMA, format_checker=FormatChecker())
        self.request = copy.deepcopy(EXAMPLE)

    def test_example(self):
        Draft202012Validator.check_schema(SCHEMA)
        self.validator.validate(self.request)

    def test_unknown_owner_cannot_be_submitted(self):
        self.request['ownerID'] = 'someone-else'
        self.assertTrue(list(self.validator.iter_errors(self.request)))

    def test_images_are_rejected_in_text_only_version(self):
        self.request['report']['assets'] = [{'path': '/private/image.png'}]
        self.assertTrue(list(self.validator.iter_errors(self.request)))

    def test_invalid_uuid_is_rejected(self):
        self.request['report']['metrics'][0]['id'] = 'invalid'
        self.assertTrue(list(self.validator.iter_errors(self.request)))

    def test_unsupported_version_is_rejected(self):
        self.request['schemaVersion'] = 2
        self.assertTrue(list(self.validator.iter_errors(self.request)))


if __name__ == '__main__':
    unittest.main()
