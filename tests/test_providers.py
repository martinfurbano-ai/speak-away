"""Speak Away must work with zero API keys, and use a key only when the user adds one."""

import unittest

from speakaway.providers import resolve


class ResolveProviders(unittest.TestCase):
    def test_no_keys_means_everything_runs_locally(self):
        chosen = resolve({"stt": "auto", "brain": "auto"}, keys=set())
        self.assertEqual(chosen, {"stt": "local", "brain": "none"})

    def test_auto_keeps_dictation_local_and_uses_a_key_only_for_the_brain(self):
        chosen = resolve({"stt": "auto", "brain": "auto"}, keys={"groq"})
        self.assertEqual(chosen, {"stt": "local", "brain": "groq"})

    def test_cloud_dictation_only_when_chosen_on_purpose(self):
        chosen = resolve({"stt": "groq", "brain": "auto"}, keys={"groq"})
        self.assertEqual(chosen, {"stt": "groq", "brain": "groq"})

    def test_a_key_that_cannot_transcribe_is_ignored_for_dictation(self):
        chosen = resolve({"stt": "anthropic", "brain": "auto"}, keys={"anthropic"})
        self.assertEqual(chosen, {"stt": "local", "brain": "anthropic"})

    def test_explicit_choice_without_its_key_falls_back_to_local(self):
        chosen = resolve({"stt": "openai", "brain": "anthropic"}, keys=set())
        self.assertEqual(chosen, {"stt": "local", "brain": "none"})

    def test_explicit_choice_with_its_key_is_respected(self):
        chosen = resolve({"stt": "local", "brain": "anthropic"}, keys={"anthropic", "openai"})
        self.assertEqual(chosen, {"stt": "local", "brain": "anthropic"})

    def test_mcp_brain_never_needs_a_key(self):
        chosen = resolve({"stt": "auto", "brain": "mcp"}, keys=set())
        self.assertEqual(chosen, {"stt": "local", "brain": "mcp"})

    def test_does_not_mutate_the_settings_it_receives(self):
        settings = {"stt": "auto", "brain": "auto"}
        resolve(settings, keys={"openai"})
        self.assertEqual(settings, {"stt": "auto", "brain": "auto"})


if __name__ == "__main__":
    unittest.main()
