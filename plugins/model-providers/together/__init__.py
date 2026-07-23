"""Together AI provider profile.

Together AI hosts 200+ open models (Llama, DeepSeek, Qwen, MiniMax, Gemma, …)
behind an OpenAI-compatible chat-completions endpoint. Model IDs use the
``org/model-name`` namespace from https://www.together.ai/models — not OpenAI
flat names like ``gpt-4o``.
"""

from providers import register_provider
from providers.base import ProviderProfile


together = ProviderProfile(
    name="together",
    aliases=("togetherai", "together-ai", "together-ai-api"),
    display_name="Together AI",
    description="Together AI — OpenAI-compatible open-model inference",
    signup_url="https://api.together.ai/settings/api-keys",
    env_vars=("TOGETHER_API_KEY", "TOGETHER_BASE_URL"),
    # Current OpenAI-compat docs use api.together.ai; api.together.xyz still
    # resolves and is registered as a reverse-mapping alias in model_metadata.
    base_url="https://api.together.ai/v1",
    auth_type="api_key",
    # Cheap/fast chat model for compression, titles, session search, etc.
    default_aux_model="deepseek-ai/DeepSeek-V4-Flash",
    # Curated safety net when the live /models catalog fetch fails. Prefer
    # agentic / tool-calling models that Hermes can actually drive.
    fallback_models=(
        "deepseek-ai/DeepSeek-V4-Pro",
        "deepseek-ai/DeepSeek-V4-Flash",
        "Qwen/Qwen3.7-Plus",
        "meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8",
        "MiniMaxAI/MiniMax-M2.7",
    ),
)

register_provider(together)
