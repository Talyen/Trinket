"""Bounded first-read Markdown over complete playthrough analysis."""

import json


def render_agent_preview(report):
    budget = 12_000
    shortened = False

    def field(value):
        nonlocal shortened
        text = json.dumps(value, ensure_ascii=False) if isinstance(value, (dict, list)) else str(value)
        text = ' '.join(text.split()).replace('`', "'")
        if len(text) > 600:
            shortened = True
            return text[:600] + '… [field shortened]'
        return text

    metrics = report['metrics']
    outcomes = {key: value for key, value in metrics['outcomes'].items() if key not in ('byAttempt', 'sequences')}
    sections = [
        '# Playthrough summary',
        '## Experiment\n\n' + '\n'.join(f'- {key}: {field(value)}' for key, value in report['experiment'].items()),
        f"Verdict: {field(report['verdict'])}\n\nConfidence: {field(report['confidence'])}",
        '## Aggregate metrics\n\n' + '\n'.join(f'- {name}: {field(value)}' for name, value in (
            ('Careers', metrics['careers']), ('Outcomes', outcomes), ('Economy', metrics['economy']))),
        '## Limitations\n\n' + '\n'.join(f'- {field(value)}' for value in report['limitations']),
        '## Findings',
    ]
    # Analysis has already used the full trajectory. Rendering order cannot hide
    # a late-run warning behind a large collection of informational findings.
    for insight in sorted(report['insights'], key=lambda item: item['severity'] == 'info'):
        sections.append(f"### {field(insight['severity'])}: {field(insight['title'])}\n\n"
                        f"{field(insight['observation'])}\n\n{field(insight['recommendation'])}")
    sections.append('## Next experiments\n\n' + '\n'.join(f'- {field(value)}' for value in report['nextExperiments']))
    failures = metrics['battleFailures']
    sections.append(f"## Failure contexts\n\nTotal non-victory outcomes: {failures['total']}")
    for label, key in (('Contexts (highest frequency first)', 'byContext'), ('Seed/attempt examples', 'examples')):
        rows = failures[key]
        sections.append(f"{label}: showing {min(5, len(rows))} of {len(rows)}; {max(0, len(rows) - 5)} omitted.\n\n"
                        + '\n'.join(f'- {field(row)}' for row in rows[:5]))

    footer = (
        '\n\n## Complete evidence\n\n'
        '[Complete analysis](report-agent.json): `metrics.outcomes.byAttempt`, '
        '`metrics.outcomes.sequences`, `metrics.stageReachCounts`, '
        '`metrics.battleFailures.byContext`, `metrics.battleFailures.examples`, '
        '`metrics.workerMetrics`, and `metrics.pairedComparison` (including outcome transitions).\n'
        '[Worker results](report.json) retain full evidence references; '
        '[Human report](report.html) presents the cohort. Retrieve only relevant fields or careers.\n'
    )
    # Reserve a fixed notice allowance before selecting complete blocks.
    remaining = budget - len(footer) - 200
    included = []
    omitted = 0
    for section in sections:
        if len(section) + 2 <= remaining:
            included.append(section)
            remaining -= len(section) + 2
        else:
            omitted += 1
    notice = f'\n\nPreview omissions: {omitted} blocks omitted by the character budget; '
    notice += 'oversized fields were shortened.' if shortened else 'no fields shortened.'
    return '\n\n'.join(included) + notice + footer
