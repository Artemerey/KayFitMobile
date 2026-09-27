import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/feedback/secure_uuid.dart';
import '../models/chat_message.dart';

const chatDeliveryStorageKey = 'chat_delivery_operations_v1';

enum ChatDeliveryStage {
  requestCreated,
  apiResponseReceived,
  responseParsed,
  durableReceived,
  rendered,
}

enum ChatDeliveryErrorCode {
  transportFailure,
  invalidResponse,
  durableReceiveFailure,
  renderFailure,
}

@immutable
class ChatDeliveryFailure {
  const ChatDeliveryFailure({
    required this.clientOperationId,
    required this.stage,
    required this.code,
  });

  final String clientOperationId;
  final ChatDeliveryStage stage;
  final ChatDeliveryErrorCode code;
}

@immutable
class ChatDeliveryOperation {
  const ChatDeliveryOperation({
    required this.clientOperationId,
    required this.accountId,
    required this.stage,
    required this.createdAt,
    this.serverMessageId,
    this.assistantContent,
    this.assistantCreatedAt,
    this.correlationId,
    this.runId,
    this.saveOperationId,
  });

  final String clientOperationId;
  final int accountId;
  final ChatDeliveryStage stage;
  final DateTime createdAt;
  final int? serverMessageId;
  final String? assistantContent;
  final DateTime? assistantCreatedAt;
  final String? correlationId;
  final String? runId;
  final String? saveOperationId;

  ChatDeliveryOperation copyWith({
    ChatDeliveryStage? stage,
    int? serverMessageId,
    String? assistantContent,
    DateTime? assistantCreatedAt,
    String? correlationId,
    String? runId,
    String? saveOperationId,
  }) => ChatDeliveryOperation(
    clientOperationId: clientOperationId,
    accountId: accountId,
    stage: stage ?? this.stage,
    createdAt: createdAt,
    serverMessageId: serverMessageId ?? this.serverMessageId,
    assistantContent: assistantContent ?? this.assistantContent,
    assistantCreatedAt: assistantCreatedAt ?? this.assistantCreatedAt,
    correlationId: correlationId ?? this.correlationId,
    runId: runId ?? this.runId,
    saveOperationId: saveOperationId ?? this.saveOperationId,
  );

  ChatMessage? toMessage() {
    final content = assistantContent;
    final messageCreatedAt = assistantCreatedAt;
    if (content == null || messageCreatedAt == null) return null;
    return ChatMessage(
      id: serverMessageId,
      role: 'assistant',
      content: content,
      createdAt: messageCreatedAt,
      clientOperationId: clientOperationId,
      correlationId: correlationId,
      runId: runId,
    );
  }

  Map<String, Object?> toJson() => {
    'client_operation_id': clientOperationId,
    'account_id': accountId,
    'stage': stage.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    if (serverMessageId != null) 'server_message_id': serverMessageId,
    if (assistantContent != null) 'assistant_content': assistantContent,
    if (assistantCreatedAt != null)
      'assistant_created_at': assistantCreatedAt!.toUtc().toIso8601String(),
    if (correlationId != null) 'correlation_id': correlationId,
    if (runId != null) 'run_id': runId,
    if (saveOperationId != null) 'save_operation_id': saveOperationId,
  };

  factory ChatDeliveryOperation.fromJson(Map<String, dynamic> json) =>
      ChatDeliveryOperation(
        clientOperationId: json['client_operation_id'] as String,
        accountId: (json['account_id'] as num).toInt(),
        stage: ChatDeliveryStage.values.byName(json['stage'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        serverMessageId: (json['server_message_id'] as num?)?.toInt(),
        assistantContent: json['assistant_content'] as String?,
        assistantCreatedAt: json['assistant_created_at'] == null
            ? null
            : DateTime.parse(json['assistant_created_at'] as String),
        correlationId: json['correlation_id'] as String?,
        runId: json['run_id'] as String?,
        saveOperationId: json['save_operation_id'] as String?,
      );
}

class ChatDeliveryStorage {
  ChatDeliveryStorage(this.preferences);

  final SharedPreferences preferences;

  List<ChatDeliveryOperation> readForAccount(int accountId) => _readAll()
      .where((operation) => operation.accountId == accountId)
      .toList();

  ChatDeliveryOperation? readOperation(String clientOperationId) {
    for (final operation in _readAll()) {
      if (operation.clientOperationId == clientOperationId) return operation;
    }
    return null;
  }

  Future<ChatDeliveryOperation> create(int accountId) async {
    final operation = ChatDeliveryOperation(
      clientOperationId: SecureUuid.v4(),
      accountId: accountId,
      stage: ChatDeliveryStage.requestCreated,
      createdAt: DateTime.now().toUtc(),
    );
    await _upsert(operation);
    return operation;
  }

  Future<void> markApiReceived(ChatDeliveryOperation operation) =>
      _upsert(operation.copyWith(stage: ChatDeliveryStage.apiResponseReceived));

  ChatMessage parseResponse(
    ChatDeliveryOperation operation,
    Map<String, dynamic> response,
  ) {
    final rawMessage = response['message'];
    if (rawMessage is! Map) {
      throw const FormatException('chat_message_missing');
    }
    final json = Map<String, dynamic>.from(rawMessage);
    late final ChatMessage message;
    try {
      message = ChatMessage.fromJson({
        ...json,
        'client_operation_id': operation.clientOperationId,
      });
    } on Object {
      throw const FormatException('chat_message_invalid');
    }
    if (message.role != 'assistant' || message.content.trim().isEmpty) {
      throw const FormatException('chat_message_invalid');
    }
    return message;
  }

  Future<void> markParsed(
    ChatDeliveryOperation operation,
    ChatMessage message,
  ) => _upsert(
    operation.copyWith(
      stage: ChatDeliveryStage.responseParsed,
      serverMessageId: message.id,
      assistantContent: message.content,
      assistantCreatedAt: message.createdAt,
      correlationId: message.correlationId,
      runId: message.runId,
    ),
  );

  Future<ChatDeliveryOperation> markDurableReceived(
    ChatDeliveryOperation operation,
    ChatMessage message,
  ) async {
    final durable = operation.copyWith(
      stage: ChatDeliveryStage.durableReceived,
      serverMessageId: message.id,
      assistantContent: message.content,
      assistantCreatedAt: message.createdAt,
      correlationId: message.correlationId,
      runId: message.runId,
    );
    await _upsert(durable);
    return durable;
  }

  Future<void> markRendered(String clientOperationId) async {
    ChatDeliveryOperation? operation;
    for (final candidate in _readAll()) {
      if (candidate.clientOperationId == clientOperationId) {
        operation = candidate;
        break;
      }
    }
    if (operation == null ||
        operation.stage.index < ChatDeliveryStage.durableReceived.index ||
        operation.stage == ChatDeliveryStage.rendered) {
      return;
    }
    await _upsert(operation.copyWith(stage: ChatDeliveryStage.rendered));
  }

  List<ChatMessage> recoverMessages(int accountId) => readForAccount(accountId)
      .where(
        (operation) =>
            operation.stage.index >= ChatDeliveryStage.durableReceived.index,
      )
      .map((operation) => operation.toMessage())
      .whereType<ChatMessage>()
      .toList();

  List<ChatDeliveryOperation> _readAll() {
    final raw = preferences.getString(chatDeliveryStorageKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
            (value) => ChatDeliveryOperation.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _upsert(ChatDeliveryOperation operation) async {
    final all = _readAll();
    final existing = all.indexWhere(
      (candidate) => candidate.clientOperationId == operation.clientOperationId,
    );
    final updated = [...all];
    if (existing == -1) {
      updated.add(operation);
    } else if (updated[existing].stage.index <= operation.stage.index) {
      updated[existing] = operation;
    } else {
      return;
    }
    await preferences.setString(
      chatDeliveryStorageKey,
      jsonEncode(updated.map((value) => value.toJson()).toList()),
    );
  }
}

/// Emits the render acknowledgment only after Flutter has completed a frame
/// containing [child]. Rebuilds for the same delivery identity are idempotent.
class ChatDeliveryRenderAck extends StatefulWidget {
  const ChatDeliveryRenderAck({
    super.key,
    required this.deliveryId,
    required this.onRendered,
    required this.child,
  });

  final String? deliveryId;
  final VoidCallback onRendered;
  final Widget child;

  @override
  State<ChatDeliveryRenderAck> createState() => _ChatDeliveryRenderAckState();
}

class _ChatDeliveryRenderAckState extends State<ChatDeliveryRenderAck> {
  String? _acknowledgedId;

  @override
  void initState() {
    super.initState();
    _scheduleAcknowledgment();
  }

  @override
  void didUpdateWidget(covariant ChatDeliveryRenderAck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deliveryId != widget.deliveryId) _scheduleAcknowledgment();
  }

  void _scheduleAcknowledgment() {
    final deliveryId = widget.deliveryId;
    if (deliveryId == null || deliveryId == _acknowledgedId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.deliveryId != deliveryId) return;
      _acknowledgedId = deliveryId;
      widget.onRendered();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

extension ChatMessageDeliveryDedup on Iterable<ChatMessage> {
  List<ChatMessage> deduplicatedByDeliveryIdentity() {
    final seen = <String>{};
    final result = <ChatMessage>[];
    for (final message in this) {
      final key = message.deliveryKey;
      if (key == null || seen.add(key)) result.add(message);
    }
    return result;
  }
}
