"""Unit tests for the Together AI provider profile.

Pins identity, aliases, and catalog defaults without going live.
"""

from __future__ import annotations

import pytest


@pytest.fixture
def together_profile():
    """Resolve the registered Together profile through the real discovery path."""
    import model_tools  # noqa: F401
    import providers

    profile = providers.get_provider_profile("together")
    assert profile is not None, "together provider profile must be registered"
    return profile


class TestTogetherIdentity:
    def test_core_fields(self, together_profile):
        p = together_profile
        assert p.name == "together"
        assert p.auth_type == "api_key"
        assert p.base_url == "https://api.together.ai/v1"
        assert "TOGETHER_API_KEY" in p.env_vars
        assert "TOGETHER_BASE_URL" in p.env_vars

    def test_display_metadata_present(self, together_profile):
        assert together_profile.display_name
        assert together_profile.description
        assert together_profile.signup_url.startswith("https://")


class TestTogetherAliases:
    @pytest.mark.parametrize("alias", ["togetherai", "together-ai", "together-ai-api"])
    def test_alias_resolves_via_registry(self, together_profile, alias):
        import providers

        resolved = providers.get_provider_profile(alias)
        assert resolved is not None
        assert resolved.name == "together"

    def test_aliases_declared_on_profile(self, together_profile):
        assert "togetherai" in together_profile.aliases
        assert "together-ai" in together_profile.aliases


class TestTogetherModelDefaults:
    def test_aux_model_is_namespaced(self, together_profile):
        aux = together_profile.default_aux_model
        assert "/" in aux, aux
        assert not aux.startswith("gpt-"), aux

    def test_fallback_models_are_namespaced(self, together_profile):
        assert together_profile.fallback_models, "expected curated fallbacks"
        for model in together_profile.fallback_models:
            assert "/" in model, model


class TestTogetherUrlMapping:
    def test_together_ai_host_maps_to_provider(self):
        from agent.model_metadata import _infer_provider_from_url

        assert _infer_provider_from_url("https://api.together.ai/v1") == "together"

    def test_legacy_xyz_host_maps_to_provider(self):
        from agent.model_metadata import _infer_provider_from_url

        assert _infer_provider_from_url("https://api.together.xyz/v1") == "together"


class TestTogetherNormalize:
    @pytest.mark.parametrize("alias", ["together", "togetherai", "together-ai"])
    def test_normalize_provider(self, alias):
        from hermes_cli.models import normalize_provider

        assert normalize_provider(alias) == "together"
