import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("prompt_eval", Path(__file__).with_name("prompt_eval.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def result(revision="a", **kwargs):
    data = {"fixtureHash":"same", "mode":"offline_mock", "model":"fake", "endpointHost":"example.invalid", "revision":revision,
            "cases":[{"id":"one","repeat":0,"title":"样本","kind":"chat","input":"测试","history":[],"characterPrompt":"角色","checks":[],"status":"completed","output":"正文","requests":[],"firstPassValid":True,"finalValid":True}]}
    return dict(data, **kwargs)


class ReportTests(unittest.TestCase):
    def test_different_models_rejected(self):
        with self.assertRaisesRegex(ValueError, "model"):
            module.build_report(result(), result("b", model="different"))

    def test_live_and_mock_cannot_be_compared(self):
        with self.assertRaisesRegex(ValueError, "mode"):
            module.build_report(result(), result("b", mode="live"))

    def test_missing_samples_not_silently_dropped(self):
        with self.assertRaisesRegex(ValueError, "sets differ"):
            module.build_report(result(), result("b", cases=[]))

    def test_report_is_reproducible_and_marks_mock(self):
        first = module.build_report(result(), result("b"))
        self.assertEqual(first, module.build_report(result(), result("b")))
        self.assertIn("Synthetic", first["note"])
        self.assertEqual({v["revision"] for v in first["pairs"][0]["variants"]}, {"a","b"})


if __name__ == "__main__":
    unittest.main()
