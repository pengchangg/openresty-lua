local semaphore = require "ngx.semaphore"
local core_table = require 'core.table'
local new_table = core_table.new
local del_table = core_table.release
local clear_table = core_table.clear
local t_remove = table.remove
local encode = core.cjson.encode
local post = core.http.post

local ffi_cdef = core.ffi.cdef
local ffi_load = core.ffi.load

local get_host_from_url = core.dns.get_host_from_url

local update_time = ngx.update_time
local localtime = ngx.localtime

ffi_cdef[[
	typedef struct _log_producer_config_tag	{
		char * key;
		char * value;
	}log_producer_config_tag;

	typedef struct _log_producer_config	{
		char * endpoint;
		char * project;
		char * logstore;
		char * accessKeyId;
		char * accessKey;
		char * securityToken;
		char * topic;
		char * source;
		pthread_mutex_t* securityTokenLock;
		log_producer_config_tag * tags;
		int32_t tagAllocSize;
		int32_t tagCount;

		int32_t sendThreadCount;

		int32_t packageTimeoutInMS;
		int32_t logCountPerPackage;
		int32_t logBytesPerPackage;
		int32_t maxBufferBytes;
		int32_t logQueueSize;

		char * netInterface;
		char * remote_address;
		int32_t connectTimeoutSec;
		int32_t sendTimeoutSec;
		int32_t destroyFlusherWaitTimeoutSec;
		int32_t destroySenderWaitTimeoutSec;

		int32_t compressType; // default lz4, 0 no compress, 1 lz4
		int32_t using_https; // default http, 0 http, 1 https

	}log_producer_config;

	log_producer_config * create_log_producer_config();
	void log_producer_config_set_endpoint(log_producer_config * config, const char * endpoint);
	void log_producer_config_set_project(log_producer_config * config, const char * project);
	void log_producer_config_set_logstore(log_producer_config * config, const char * logstore);
	void log_producer_config_set_access_id(log_producer_config * config, const char * access_id);
	void log_producer_config_set_access_key(log_producer_config * config, const char * access_id);
	void log_producer_config_reset_security_token(log_producer_config * config, const char * access_id, const char * access_secret, const char * security_token);
	void log_producer_config_get_security(log_producer_config * config, char ** access_id, char ** access_secret, char ** security_token);
	void log_producer_config_set_topic(log_producer_config * config, const char * topic);
	void log_producer_config_set_source(log_producer_config * config, const char * source);
	void log_producer_config_add_tag(log_producer_config * config, const char * key, const char * value);
	void log_producer_config_set_packet_timeout(log_producer_config * config, int32_t time_out_ms);
	void log_producer_config_set_packet_log_count(log_producer_config * config, int32_t log_count);
	void log_producer_config_set_packet_log_bytes(log_producer_config * config, int32_t log_bytes);
	void log_producer_config_set_max_buffer_limit(log_producer_config * config, int64_t max_buffer_bytes);
	void log_producer_config_set_send_thread_count(log_producer_config * config, int32_t thread_count);
	void log_producer_config_set_net_interface(log_producer_config * config, const char * net_interface);
	void log_producer_config_set_remote_address(log_producer_config * config, const char * remote_address);
	void log_producer_config_set_connect_timeout_sec(log_producer_config * config, int32_t connect_timeout_sec);
	void log_producer_config_set_send_timeout_sec(log_producer_config * config, int32_t send_timeout_sec);
	void log_producer_config_set_destroy_flusher_wait_sec(log_producer_config * config, int32_t destroy_flusher_wait_sec);
	void log_producer_config_set_destroy_sender_wait_sec(log_producer_config * config, int32_t destroy_sender_wait_sec);
	void log_producer_config_set_compress_type(log_producer_config * config, int32_t compress_type);
	void log_producer_config_set_using_http(log_producer_config * config, int32_t using_https);
	void log_producer_config_set_log_queue_size(log_producer_config * config, int32_t log_queue_size);
	void destroy_log_producer_config(log_producer_config * config);
	int log_producer_config_is_valid(log_producer_config * config);
	
	typedef struct _log_producer_client	{
		volatile int32_t valid_flag;
		int32_t log_level;
		void * private_data;
	}log_producer_client;
	
	typedef struct _log_producer {
		log_producer_client * root_client;
	}log_producer;
	
	log_producer * create_log_producer(log_producer_config * config, on_log_producer_send_done_function send_done_function);
	log_producer_client * get_log_producer_client(log_producer * producer, const char * config_name);
	int log_producer_client_add_log(log_producer_client * client, int32_t kv_count, ...);
	void destroy_log_producer(log_producer * producer);
	void log_producer_env_destroy();
]]

local ok, lib = pcall(ffi_load, (core.myor_prefix or './zxor') .. "/lualib/third/aliyun/sls/liblog_c_sdk.so")
if not ok then
    core.log.info('ERROR: load snappy lib failed. err = ', lib)
    lib = nil
end

local _M = { _VERSION = '0.01' }

local mt = { __index = _M }

local _on_log_send_done = function(config_name, result, log_bytes, compress_bytes, req_id, message, raw_buffer)
	if result == 0 then
		req_id = req_id or ''
		message = message or ''
		--ok
	else
		req_id = req_id or ''
		message = message or ''
		--failed
	end
end

_M.new = function(self, opt)
	if not lib then return nil end
	local ctx = {
		lib = lib,
		on_log_send_done = opt.on_log_send_done or _on_log_send_done,
		endpoint = opt.endpoint,
		project = opt.project,
		logstore = opt.logstore,
		access_id = opt.access_id,
		access_key = opt.access_key,
		security_token = opt.security_token,
		topic = opt.topic,
		tags = opt.tags,
		packet = {
			log_bytes = opt.packet_log_bytes or (4096*1024),
			log_count = opt.packet_log_count or 4096,
			timeout = opt.packet_timeout or 3000,
		},
		max_buffer_limit = opt.max_buffer_limit or (64*1024*1024),
		send_thread_count = opt.send_thread_count or 4,
		compress_type = opt.compress_type or 1,
		connect_timeout = opt.connect_timeout or 10,
		send_timeout = opt.send_timeout or 15,
		destroy_flusher_wait = opt.destroy_flusher_wait or 1,
		destroy_sender_wait = opt.destroy_sender_wait or 1,
	}
	
    return setmetatable(ctx, mt)
end

_M.start = function(self)
	if self.producer or not self.client then return end
	
	local config = self.lib.create_log_producer_config();
	self.lib.log_producer_config_set_endpoint(config,self.endpoint)
	self.lib.log_producer_config_set_project(config,self.logstore)
	self.lib.log_producer_config_set_logstore(config,self.endpoint)
	self.lib.log_producer_config_set_access_id(config,self.access_id)
	self.lib.log_producer_config_set_access_key(config,self.access_key)
	self.lib.log_producer_config_set_endpoint(config,self.endpoint)
	if self.security_token then
		self.lib.log_producer_config_reset_security_token(config,self.access_id,self.access_key,self.security_token)
	end
	self.lib.log_producer_config_set_topic(config,self.topic)
	for tag,val in pairs(self.tags or {}) do
		self.lib.log_producer_config_add_tag(config,tag,val)
	end
	self.lib.log_producer_config_set_packet_log_bytes(config,self.packet.log_bytes)
	self.lib.log_producer_config_set_packet_log_count(config,self.packet.log_count)
	self.lib.log_producer_config_set_packet_timeout(config,self.packet.timeout)
	self.lib.log_producer_config_set_max_buffer_limit(config,self.max_buffer_limit)
	self.lib.log_producer_config_set_send_thread_count(config,self.send_thread_count)
	self.lib.log_producer_config_set_compress_type(config,self.compress_type)
	self.lib.log_producer_config_set_connect_timeout_sec(config,self.send_timeout)
	self.lib.log_producer_config_set_send_timeout_sec(config,self.max_buffer_limit)
	self.lib.log_producer_config_set_destroy_flusher_wait_sec(config,self.destroy_flusher_wait)
	self.lib.log_producer_config_set_destroy_sender_wait_sec(config,self.destroy_sender_wait)
	self.lib.log_producer_config_set_net_interface(config,nil)
	
	self.producer = self.lib.create_log_producer(self.config,self.on_log_send_done)
	
	if not self.producer then return nil,'create producer failed' end
	self.client = self.lib.get_log_producer_client(self.producer, nil)
	if not self.client then
		self.lib.destroy_log_producer(self.producer)
		self.lib.log_producer_env_destroy()
		return nil,'create producer failed 2' 
	end
	
	return true
end

_M.stop = function(self)
	self.client = nil
	self.lib.destroy_log_producer(self.producer)
	self.producer = nil
	self.lib.log_producer_env_destroy()
end

_M.append = function(self,logs)
	if not self.client then return false,'not working' end
	--self.lib.log_producer_client_add_log(self.client,#logs,logs)
end

return _M