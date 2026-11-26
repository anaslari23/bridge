import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/core/bridge_protocol.dart';

void main() {
  test('accepts only an exact delegation marker with two string fields', () {
    expect(
      BridgeProtocol.parseDelegation(
        '<<BRIGADE_DELEGATE>>{"targetNodeId":"tab-2","instruction":"check the API"}',
      ),
      const DelegationDirective(
        targetNodeId: 'tab-2',
        instruction: 'check the API',
      ),
    );
    expect(
      BridgeProtocol.parseDelegation(
        '<<BRIGADE_DELEGATE>>{"targetNodeId":"tab-2","instruction":"check"} extra',
      ),
      isNull,
    );
  });

  test('rejects prose, malformed JSON, unknown fields, and empty values', () {
    expect(BridgeProtocol.parseDelegation('I will ask another app.'), isNull);
    expect(BridgeProtocol.parseDelegation('<<BRIGADE_DELEGATE>>{bad'), isNull);
    expect(
      BridgeProtocol.parseDelegation(
        '<<BRIGADE_DELEGATE>>{"targetNodeId":"x","instruction":"y","extra":true}',
      ),
      isNull,
    );
    expect(
      BridgeProtocol.parseDelegation(
        '<<BRIGADE_DELEGATE>>{"targetNodeId":" ","instruction":""}',
      ),
      isNull,
    );
  });
}
