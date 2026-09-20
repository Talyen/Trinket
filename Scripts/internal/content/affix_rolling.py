"""Affix rolling policy attached to the canonical trigger fields."""
from __future__ import annotations

from internal.content.common import GENERATED_DIR, swift_escape, write_generated_file


def rolling_policies(families: list[dict]) -> dict[str, dict]:
    policies = {}
    orders = set()
    for family in families:
        for field in family['fields']:
            policy = field.get('affix_roll')
            if policy is None:
                continue
            label = field['name']
            if not isinstance(policy, dict):
                raise ValueError(f'Invalid affix_roll for {label}')
            if set(policy) == {'reason'}:
                if not isinstance(policy['reason'], str) or not policy['reason'].strip():
                    raise ValueError(f'Non-rollable affix field {label} needs a reason')
            elif set(policy) == {'kind', 'order'}:
                kind, order = policy['kind'], policy['order']
                if kind not in {'int', 'percent'} or field['type'] != {'int': 'Int', 'percent': 'Double'}[kind]:
                    raise ValueError(f'Affix roll kind does not match type for {label}')
                if type(order) is not int or order < 0 or order in orders:
                    raise ValueError(f'Affix roll order must be unique and nonnegative: {label}')
                orders.add(order)
            else:
                raise ValueError(f'Invalid affix_roll for {label}: use kind/order or reason')
            policies[label] = policy
    return policies


def validate_affix_rolling(raw: str, row_id: str) -> None:
    from internal.content.content_codegen_triggers import _trigger_families, parse_trigger_values
    policies = rolling_policies(_trigger_families())
    missing = set(parse_trigger_values(raw, row_id)) - policies.keys()
    if missing:
        raise ValueError(f'{row_id}: affix trigger fields need explicit affix_roll policy: {sorted(missing)}')


def generate_affix_rolling(families: list[dict]) -> None:
    policies = rolling_policies(families)
    ordered = sorted(((name, policy) for name, policy in policies.items() if 'order' in policy),
                     key=lambda entry: entry[1]['order'])
    lines = ['extension CombatTraitTriggers {',
             '    // Order preserves seeded roll and bump selection behavior.',
             '    static let affixMagnitudeFields: [AffixMagnitudeField] = [']
    for name, policy in ordered:
        lines.append(f'        .{policy["kind"]}(\\.{name}, name: "{name}"),')
    lines += ['    ]', '', '    static let nonRollableAffixFields: [String: String] = [']
    for name, policy in policies.items():
        if 'reason' in policy:
            lines.append(f'        "{name}": "{swift_escape(policy["reason"])}",')
    lines += ['    ]', '}']
    write_generated_file(GENERATED_DIR / 'AffixRolling.generated.swift', '\n'.join(lines) + '\n')
