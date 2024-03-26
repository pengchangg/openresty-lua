-- Copyright (C) Dejiang Zhu(doujiang24)

local _M = {
    [0]     = 'Success',
	[-1]	= "UNKNOWN_SERVER_ERROR - The server experienced an unexpected error when processing the request.",
	[1]		= "OFFSET_OUT_OF_RANGE - The requested offset is not within the range of offsets maintained by the server.",
	[2]		= "CORRUPT_MESSAGE - This message has failed its CRC checksum, exceeds the valid size, has a null key for a compacted topic, or is otherwise corrupt.",
	[3]		= "UNKNOWN_TOPIC_OR_PARTITION - This server does not host this topic-partition.",
	[4]		= "INVALID_FETCH_SIZE - The requested fetch size is invalid.",
	[5]		= "LEADER_NOT_AVAILABLE - There is no leader for this topic-partition as we are in the middle of a leadership election.",
	[6]		= "NOT_LEADER_OR_FOLLOWER - For requests intended only for the leader, this error indicates that the broker is not the current leader. For requests intended for any replica, this error indicates that the broker is not a replica of the topic partition.",
	[7]		= "REQUEST_TIMED_OUT - The request timed out.",
	[8]		= "BROKER_NOT_AVAILABLE - The broker is not available.",
	[9]		= "REPLICA_NOT_AVAILABLE - The replica is not available for the requested topic-partition. Produce/Fetch requests and other requests intended only for the leader or follower return NOT_LEADER_OR_FOLLOWER if the broker is not a replica of the topic-partition.",
	[10]	= "MESSAGE_TOO_LARGE - The request included a message larger than the max message size the server will accept.",
	[11]	= "STALE_CONTROLLER_EPOCH - The controller moved to another broker.",
	[12]	= "OFFSET_METADATA_TOO_LARGE - The metadata field of the offset request was too large.",
	[13]	= "NETWORK_EXCEPTION - The server disconnected before a response was received.",
	[14]	= "COORDINATOR_LOAD_IN_PROGRESS - The coordinator is loading and hence can't process requests.",
	[15]	= "COORDINATOR_NOT_AVAILABLE - The coordinator is not available.",
	[16]	= "NOT_COORDINATOR - This is not the correct coordinator.",
	[17]	= "INVALID_TOPIC_EXCEPTION - The request attempted to perform an operation on an invalid topic.",
	[18]	= "RECORD_LIST_TOO_LARGE - The request included message batch larger than the configured segment size on the server.",
	[19]	= "NOT_ENOUGH_REPLICAS - Messages are rejected since there are fewer in-sync replicas than required.",
	[20]	= "NOT_ENOUGH_REPLICAS_AFTER_APPEND - Messages are written to the log, but to fewer in-sync replicas than required.",
	[21]	= "INVALID_REQUIRED_ACKS - Produce request specified an invalid value for required acks.",
	[22]	= "ILLEGAL_GENERATION - Specified group generation id is not valid.",
	[23]	= "INCONSISTENT_GROUP_PROTOCOL - The group member's supported protocols are incompatible with those of existing members or first group member tried to join with empty protocol type or empty protocol list.",
	[24]	= "INVALID_GROUP_ID - The configured groupId is invalid.",
	[25]	= "UNKNOWN_MEMBER_ID - The coordinator is not aware of this member.",
	[26]	= "INVALID_SESSION_TIMEOUT - The session timeout is not within the range allowed by the broker (as configured by group.min.session.timeout.ms and group.max.session.timeout.ms).",
	[27]	= "REBALANCE_IN_PROGRESS - The group is rebalancing, so a rejoin is needed.",
	[28]	= "INVALID_COMMIT_OFFSET_SIZE - The committing offset data size is not valid.",
	[29]	= "TOPIC_AUTHORIZATION_FAILED - Topic authorization failed.",
	[30]	= "GROUP_AUTHORIZATION_FAILED - Group authorization failed.",
	[31]	= "CLUSTER_AUTHORIZATION_FAILED - Cluster authorization failed.",
	[32]	= "INVALID_TIMESTAMP - The timestamp of the message is out of acceptable range.",
	[33]	= "UNSUPPORTED_SASL_MECHANISM - The broker does not support the requested SASL mechanism.",
	[34]	= "ILLEGAL_SASL_STATE - Request is not valid given the current SASL state.",
	[35]	= "UNSUPPORTED_VERSION - The version of API is not supported.",
	[36]	= "TOPIC_ALREADY_EXISTS - Topic with this name already exists.",
	[37]	= "INVALID_PARTITIONS - Number of partitions is below 1.",
	[38]	= "INVALID_REPLICATION_FACTOR - Replication factor is below 1 or larger than the number of available brokers.",
	[39]	= "INVALID_REPLICA_ASSIGNMENT - Replica assignment is invalid.",
	[40]	= "INVALID_CONFIG - Configuration is invalid.",
	[41]	= "NOT_CONTROLLER - This is not the correct controller for this cluster.",
	[42]	= "INVALID_REQUEST - This most likely occurs because of a request being malformed by the client library or the message was sent to an incompatible broker. See the broker logs for more details.",
	[43]	= "UNSUPPORTED_FOR_MESSAGE_FORMAT - The message format version on the broker does not support the request.",
	[44]	= "POLICY_VIOLATION - Request parameters do not satisfy the configured policy.",
	[45]	= "OUT_OF_ORDER_SEQUENCE_NUMBER - The broker received an out of order sequence number.",
	[46]	= "DUPLICATE_SEQUENCE_NUMBER - The broker received a duplicate sequence number.",
	[47]	= "INVALID_PRODUCER_EPOCH - Producer attempted to produce with an old epoch.",
	[48]	= "INVALID_TXN_STATE - The producer attempted a transactional operation in an invalid state.",
	[49]	= "INVALID_PRODUCER_ID_MAPPING - The producer attempted to use a producer id which is not currently assigned to its transactional id.",
	[50]	= "INVALID_TRANSACTION_TIMEOUT - The transaction timeout is larger than the maximum value allowed by the broker (as configured by transaction.max.timeout.ms).",
	[51]	= "CONCURRENT_TRANSACTIONS - The producer attempted to update a transaction while another concurrent operation on the same transaction was ongoing.",
	[52]	= "TRANSACTION_COORDINATOR_FENCED - Indicates that the transaction coordinator sending a WriteTxnMarker is no longer the current coordinator for a given producer.",
	[53]	= "TRANSACTIONAL_ID_AUTHORIZATION_FAILED - Transactional Id authorization failed.",
	[54]	= "SECURITY_DISABLED - Security features are disabled.",
	[55]	= "OPERATION_NOT_ATTEMPTED - The broker did not attempt to execute this operation. This may happen for batched RPCs where some operations in the batch failed, causing the broker to respond without trying the rest.",
	[56]	= "KAFKA_STORAGE_ERROR - Disk error when trying to access log file on the disk.",
	[57]	= "LOG_DIR_NOT_FOUND - The user-specified log directory is not found in the broker config.",
	[58]	= "SASL_AUTHENTICATION_FAILED - SASL Authentication failed.",
	[59]	= "UNKNOWN_PRODUCER_ID - This exception is raised by the broker if it could not locate the producer metadata associated with the producerId in question. This could happen if, for instance, the producer's records were deleted because their retention time had elapsed. Once the last records of the producerId are removed, the producer's metadata is removed from the broker, and future appends by the producer will return this exception.",
	[60]	= "REASSIGNMENT_IN_PROGRESS - A partition reassignment is in progress.",
	[61]	= "DELEGATION_TOKEN_AUTH_DISABLED - Delegation Token feature is not enabled.",
	[62]	= "DELEGATION_TOKEN_NOT_FOUND - Delegation Token is not found on server.",
	[63]	= "DELEGATION_TOKEN_OWNER_MISMATCH - Specified Principal is not valid Owner/Renewer.",
	[64]	= "DELEGATION_TOKEN_REQUEST_NOT_ALLOWED - Delegation Token requests are not allowed on PLAINTEXT/1-way SSL channels and on delegation token authenticated channels.",
	[65]	= "DELEGATION_TOKEN_AUTHORIZATION_FAILED - Delegation Token authorization failed.",
	[66]	= "DELEGATION_TOKEN_EXPIRED - Delegation Token is expired.",
	[67]	= "INVALID_PRINCIPAL_TYPE - Supplied principalType is not supported.",
	[68]	= "NON_EMPTY_GROUP - The group is not empty.",
	[69]	= "GROUP_ID_NOT_FOUND - The group id does not exist.",
	[70]	= "FETCH_SESSION_ID_NOT_FOUND - The fetch session ID was not found.",
	[71]	= "INVALID_FETCH_SESSION_EPOCH - The fetch session epoch is invalid.",
	[72]	= "LISTENER_NOT_FOUND - There is no listener on the leader broker that matches the listener on which metadata request was processed.",
	[73]	= "TOPIC_DELETION_DISABLED - Topic deletion is disabled.",
	[74]	= "FENCED_LEADER_EPOCH - The leader epoch in the request is older than the epoch on the broker.",
	[75]	= "UNKNOWN_LEADER_EPOCH - The leader epoch in the request is newer than the epoch on the broker.",
	[76]	= "UNSUPPORTED_COMPRESSION_TYPE - The requesting client does not support the compression type of given partition.",
	[77]	= "STALE_BROKER_EPOCH - Broker epoch has changed.",
	[78]	= "OFFSET_NOT_AVAILABLE - The leader high watermark has not caught up from a recent leader election so the offsets cannot be guaranteed to be monotonically increasing.",
	[79]	= "MEMBER_ID_REQUIRED - The group member needs to have a valid member id before actually entering a consumer group.",
	[80]	= "PREFERRED_LEADER_NOT_AVAILABLE - The preferred leader was not available.",
	[81]	= "GROUP_MAX_SIZE_REACHED - The consumer group has reached its max size.",
	[82]	= "FENCED_INSTANCE_ID - The broker rejected this static consumer since another consumer with the same group.instance.id has registered with a different member.id.",
	[83]	= "ELIGIBLE_LEADERS_NOT_AVAILABLE - Eligible topic partition leaders are not available.",
	[84]	= "ELECTION_NOT_NEEDED - Leader election not needed for topic partition.",
	[85]	= "NO_REASSIGNMENT_IN_PROGRESS - No partition reassignment is in progress.",
	[86]	= "GROUP_SUBSCRIBED_TO_TOPIC - Deleting offsets of a topic is forbidden while the consumer group is actively subscribed to it.",
	[87]	= "INVALID_RECORD - This record has failed the validation on broker and hence will be rejected.",
	[88]	= "UNSTABLE_OFFSET_COMMIT - There are unstable offsets that need to be cleared.",
	[89]	= "THROTTLING_QUOTA_EXCEEDED - The throttling quota has been exceeded.",
	[90]	= "PRODUCER_FENCED - There is a newer producer with the same transactionalId which fences the current one.",
	[91]	= "RESOURCE_NOT_FOUND - A request illegally referred to a resource that does not exist.",
	[92]	= "DUPLICATE_RESOURCE - A request illegally referred to the same resource twice.",
	[93]	= "UNACCEPTABLE_CREDENTIAL - Requested credential would not meet criteria for acceptability.",
	[94]	= "INCONSISTENT_VOTER_SET - Indicates that the either the sender or recipient of a voter-only request is not one of the expected voters",
	[95]	= "INVALID_UPDATE_VERSION - The given update version was invalid.",
	[96]	= "FEATURE_UPDATE_FAILED - Unable to update finalized features due to an unexpected server error.",
	[97]	= "PRINCIPAL_DESERIALIZATION_FAILURE - Request principal deserialization failed during forwarding. This indicates an internal error on the broker cluster security setup.",
	[98]	= "SNAPSHOT_NOT_FOUND - Requested snapshot was not found",
	[99]	= "POSITION_OUT_OF_RANGE - Requested position is not greater than or equal to zero, and less than the size of the snapshot.",
	[100]	= "UNKNOWN_TOPIC_ID - This server does not host this topic ID.",
	[101]	= "DUPLICATE_BROKER_REGISTRATION - This broker ID is already in use.",
	[102]	= "BROKER_ID_NOT_REGISTERED - The given broker ID was not registered.",
	[103]	= "INCONSISTENT_TOPIC_ID - The log's topic ID did not match the topic ID in the request",
	[104]	= "INCONSISTENT_CLUSTER_ID - The clusterId in the request does not match that found on the server",
}

return _M