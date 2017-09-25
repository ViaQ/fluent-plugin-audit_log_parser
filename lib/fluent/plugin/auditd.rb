require 'time'

module Fluent
  class Auditd
    class AuditdParserException < StandardError
    end

    IN_HOST_PID = 'pid'
    IN_HOST_UID = 'uid'
    IN_HOST_AUID = 'auid'
    IN_HOST_SESSION = 'ses'
    IN_HOST_SELINUX_LABEL = 'subj'
    IN_HOST_HOSTNAME = 'hostname'
    IN_VM_AUID = 'auid'
    IN_VM_HOSTNAME = 'hostname'
    IN_VM_IMAGE = 'vm'
    IN_VM_PID = 'vm-pid'
    IN_VM_USER = 'user'
    IN_VM_EXE = 'exe'
    IN_VM_REASPON = 'reason'
    IN_VM_OPERATION = 'op'
    IN_VM_RESULT = 'res'
    IN_EVENT_TYPE = 'virt_control'

    OUT_HOST_PID = 'systemd.t.PID'
    OUT_HOST_UID = 'systemd.t.UID'
    OUT_HOST_AUID = 'systemd.t.AUDIT_LOGINUID'
    OUT_HOST_SESSION = 'systemd.t.AUDIT_SESSION'
    OUT_HOST_SELINUX_LABEL = 'systemd.t.SELINUX_CONTEXT'
    OUT_HOST_HOSTNAME = 'hostname'
    OUT_VM_AUID = 'auid'
    OUT_VM_HOSTNAME = 'container_id_short'
    OUT_VM_IMAGE = 'container_image'
    OUT_VM_PID = 'pid'
    OUT_VM_USER = 'user'
    OUT_VM_EXE = 'systemd.t.EXE'
    OUT_VM_REASPON = 'reason'
    OUT_VM_OPERATION = 'operation'
    OUT_VM_RESULT = 'result'
    OUT_EVENT_TYPE = 'docker.audit_event_type'

    TIME = 'time'
    
    def parse_auditd_line(line)
      result = {}
      vc = {}
      if metadata = /(?<g1>.*?) msg='(?<g2>.*?)'/.match(line) 
        if (!metadata['g1'].nil?) && (!metadata['g2'].nil?)
          parse_metadata(result, metadata['g1'].split)
          parse_msg(vc, metadata['g2'].split)
          result['virt_control'] = vc
        else
          handle_error "Couldn't parse message: #{line}"
        end
      else
        handle_error "Couldn't parse message: #{line}"
      end
      return normalize(result)
    end

    def parse_metadata(result, metadata)
      result[TIME] = metadata[1].sub(/msg=audit\((?<g1>.*):\d+\):/, '\k<g1>')
      for i in 2...metadata.length
        pair = metadata[i].split('=')
        insert_or_merge(result, pair[0], pair[1]) unless pair[1].nil? or pair[1] == '?'
      end
    end

    def parse_msg(result, msg)
      msg.each do |part|
        pair = part.split('=')
        insert_or_merge(result, pair[0], pair[1]) unless pair[1].nil? or pair[1] == '?'
      end
    end

    def insert_or_merge(result, key, value)
      if result[key].nil?
        result[key] = value
      elsif result[key].kind_of?(Array)
        result[key] << value
      else
        temp = result[key]
        result[key] = [value, temp]
      end
    end

    def handle_error(msg)
      raise AuditdParserException, msg
    end

    def normalize(target)
      event = {}
      event[TIME] =                 Time.at(target[TIME].to_f).utc.to_datetime.rfc3339(6)
      event[OUT_HOST_PID]           = target[IN_HOST_PID] unless target[IN_HOST_PID].nil?
      event[OUT_HOST_UID]           = target[IN_HOST_UID] unless target[IN_HOST_UID].nil?
      event[OUT_HOST_AUID]          = target[IN_HOST_AUID] unless target[IN_HOST_AUID].nil?
      event[OUT_HOST_SESSION]       = target[IN_HOST_SESSION] unless target[IN_HOST_SESSION].nil?
      event[OUT_HOST_SELINUX_LABEL] = target[IN_HOST_SELINUX_LABEL] unless target[IN_HOST_SELINUX_LABEL].nil?

      event[OUT_VM_AUID]            = target[IN_EVENT_TYPE][IN_VM_AUID] unless target[IN_EVENT_TYPE][IN_VM_AUID].nil?
      event[OUT_VM_HOSTNAME]        = target[IN_EVENT_TYPE][IN_VM_HOSTNAME] unless target[IN_EVENT_TYPE][IN_VM_HOSTNAME].nil?
      event[OUT_VM_IMAGE]           = target[IN_EVENT_TYPE][IN_VM_IMAGE] unless target[IN_EVENT_TYPE][IN_VM_IMAGE].nil?
      event[OUT_VM_PID]             = target[IN_EVENT_TYPE][IN_VM_PID] unless target[IN_EVENT_TYPE][IN_VM_PID].nil?
      event[OUT_VM_USER]            = target[IN_EVENT_TYPE][IN_VM_USER] unless target[IN_EVENT_TYPE][IN_VM_USER].nil?
      event[OUT_VM_EXE]             = target[IN_EVENT_TYPE][IN_VM_EXE] unless target[IN_EVENT_TYPE][IN_VM_EXE].nil?
      event[OUT_VM_REASPON]         = target[IN_EVENT_TYPE][IN_VM_REASPON] unless target[IN_EVENT_TYPE][IN_VM_REASPON].nil?
      event[OUT_VM_OPERATION]       = target[IN_EVENT_TYPE][IN_VM_OPERATION] unless target[IN_EVENT_TYPE][IN_VM_OPERATION].nil?
      event[OUT_VM_RESULT]          = target[IN_EVENT_TYPE][IN_VM_RESULT] unless target[IN_EVENT_TYPE][IN_VM_RESULT].nil?
      return event
    end

  end
end