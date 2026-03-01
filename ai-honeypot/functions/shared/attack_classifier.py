"""Attack classifier — regex-based prompt injection and jailbreak detection."""

import re
from typing import Any

ATTACK_PATTERNS: dict[str, list[str]] = {
    "role_override": [
        r"ignore.*(?:previous|prior|above).*instructions",
        r"you are now",
        r"act as",
        r"pretend (?:to be|you are)",
        r"new persona",
    ],
    "data_extraction": [
        r"(?:list|show|give|provide|dump).*(?:employee|user|customer|record|database)",
        r"(?:password|credential|api.?key|secret|token)",
        r"(?:salary|ssn|social security|credit card)",
    ],
    "system_prompt_leak": [
        r"(?:repeat|show|reveal|display).*(?:system|initial|original).*(?:prompt|instruction|message)",
        r"what (?:are|were) your (?:instructions|rules|guidelines)",
    ],
    "jailbreak": [
        r"(?:DAN|developer mode|god mode|sudo mode)",
        r"(?:do anything now|no restrictions|unrestricted)",
        r"(?:bypass|disable|remove).*(?:filter|safety|guard|restriction)",
    ],
    "indirect_injection": [
        r"(?:when processing|if you read|upon receiving).*(?:execute|run|perform)",
        r"(?:hidden instruction|embedded command)",
    ],
}


def classify_attack(prompt: str) -> dict[str, Any]:
    """
    Classify an attack prompt into categories with confidence.

    Returns a dict with:
      - type: primary attack type (str)
      - all_types: list of all detected types
      - techniques: list of dicts with type and matched pattern
      - confidence: float between 0.5 and 0.99
    """
    prompt_lower = prompt.lower()
    detected_types: list[str] = []
    techniques: list[dict[str, str]] = []

    for attack_type, patterns in ATTACK_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, prompt_lower):
                if attack_type not in detected_types:
                    detected_types.append(attack_type)
                techniques.append({"type": attack_type, "pattern": pattern})

    primary_type = detected_types[0] if detected_types else "unknown"
    confidence = min(0.5 + (len(techniques) * 0.15), 0.99)

    return {
        "type": primary_type,
        "all_types": detected_types,
        "techniques": techniques,
        "confidence": round(confidence, 2),
    }
