import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/daemon/lead_router.dart';

void main() {
  const claude = BridgeNode(
    id: 'claude',
    name: 'Claude',
    kind: NodeKind.browser,
    detail: '',
    capabilities: ['receive_task'],
    taskDomains: ['planning', 'general'],
    health: 'connected',
  );
  const codex = BridgeNode(
    id: 'codex',
    name: 'Codex',
    kind: NodeKind.browser,
    detail: '',
    capabilities: ['receive_task'],
    taskDomains: ['coding', 'general'],
    health: 'connected',
  );
  const chrome = BridgeNode(
    id: 'chrome',
    name: 'Chrome',
    kind: NodeKind.browser,
    detail: '',
    capabilities: ['receive_task', 'web_research'],
    taskDomains: ['web_research', 'general'],
    health: 'connected',
  );

  final router = LeadRouter();

  test('classifies supported task domains deterministically', () {
    expect(TaskDomainClassifier.classify('Plan the app architecture'),
        contains('planning'));
    expect(TaskDomainClassifier.classify('Implement the login flow'),
        contains('coding'));
    expect(TaskDomainClassifier.classify('Search the web for current pricing'),
        contains('web_research'));
    expect(TaskDomainClassifier.classify('Summarize these notes'),
        contains('general'));
  });

  test('selects the connected lead with the strongest domain match', () {
    expect(
      router.selectLead(
        taskText: 'Implement the API and fix the parser',
        connectedNodes: [claude, chrome, codex],
      )?.id,
      'codex',
    );
    expect(
      router.selectLead(
        taskText: 'Search the web for recent announcements',
        connectedNodes: [claude, codex, chrome],
      )?.id,
      'chrome',
    );
  });

  test('valid override wins and invalid or unavailable overrides are rejected',
      () {
    expect(
      router
          .selectLead(
            taskText: 'Plan the architecture',
            connectedNodes: [claude, codex],
            overrideNodeId: 'codex',
          )
          ?.id,
      'codex',
    );
    expect(
      router.selectLead(
        taskText: 'Plan the architecture',
        connectedNodes: [claude, codex],
        overrideNodeId: 'missing',
      ),
      isNull,
    );
    expect(
      router.selectLead(
        taskText: 'Plan the architecture',
        connectedNodes: [
          claude,
          codex.copyWith(health: 'unavailable'),
        ],
        overrideNodeId: 'codex',
      ),
      isNull,
    );
  });

  test('filters nodes without receive_task and returns null when none qualify',
      () {
    expect(
      router.selectLead(
        taskText: 'Do anything',
        connectedNodes: [
          const BridgeNode(
            id: 'observe-only',
            name: 'Observer',
            kind: NodeKind.browser,
            detail: '',
            taskDomains: ['general'],
            health: 'connected',
          ),
        ],
      ),
      isNull,
    );
    expect(router.selectLead(taskText: 'anything', connectedNodes: []), isNull);
  });
}
