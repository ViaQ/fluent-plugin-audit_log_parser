require "fluent/plugin/auditd"
require 'fluent/parser'
require 'fluent/time'

module Fluent
  class AuditdParser < Parser
    Plugin.register_parser("auditd", self)

    def configure(conf={})
      super
      @auditd = Auditd.new()
    end

    def parse(text)
      begin
        parsed_line = @auditd.parse_auditd_line text
        time = Time.now.to_f.round(3)
        yield time, parsed_line
      rescue Fluent::Auditd::AuditdParserException => e
        log.error e.message
        yield nil, nil
      end
    end
  end
end