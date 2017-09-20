require "fluent/plugin/auditd"

module Fluent
  class AuditdParser < Parser
    Fluent::Plugin.register_parser("auditd", self)

    desc "The format of the time field."
    config_param :time_format, :string, default: nil

    def initialize
      super
    end

    def configure(conf={})
      super
      @auditd = Auditd.new()
    end

    def parse(text)
      begin
        parsed_line = @auditd.parse_auditd_line text
        yield 1000000000, parsed_line
      rescue AuditParserException => e
        log.error e.message
        yield nil, nil
      end
    end

  end
end