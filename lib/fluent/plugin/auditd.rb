module Fluent
  class Auditd
    class AuditdParserException < StandardError
    end
    
    MSG = "msg"
    TIMESTAMP = "time"
    AUDIT = "audit"

    def parse_auditd_line(line)
      states = {}
      states[:start] = 0
      states[:key] = 1
      states[:value] = 2
      state = states[:start]
      stack = ["$"]
      line << "$"
      nested = false
      key, nested_key, value = nil
      result = {}
      for i in 0...line.length do
        if state == states[:start]
          if line[i] == "$"
            # last element
            if stack.last != "$"
              # input symbol doesn't match stack symbol
              handle_error line, result
            end
          else
            # reading new key
            # here might be an extra space
            if line[i] == " "
              next
            end
            key = line[i]
            state = states[:key]
          end
        elsif state == states[:key]
          if line[i] == "="
            # finished reading key
            state = states[:value]
            value = ""
          else
            # reading key
            key << line[i]
          end
        elsif state == states[:value]
          if line[i] == " "
            # finished reading value
            state = states[:start]
            insert(result, nested, key, nested_key, value) unless value == "?"
          elsif line[i] == "'"
            if stack.last == "'"
              # finished reading nested structure 
              stack.pop
              nested = false
              result[nested_key][key] = value
            else
              # starting reading nested structure
              stack << "'"
              nested = true
              nested_key = key
              result[nested_key] = {}
            end
            state = states[:start]
          elsif line[i] == "$"
            # end of input
            if stack.last == "$"
              insert(result, nested, key, nested_key, value) unless value == "?"
            else
              # input symbol doesn't match stack symbol
              handle_error line, result
          end
          else
            # reading value
            value << line[i]
          end
        else
          # unknown state
          handle_error line, result
        end
      end
      return result
    end

    def handle_error(line, result)
      raise AuditdParserException, (sprintf \
        "Error after processing string '%s'\nBuilt %s", line, result)
    end

    def insert(result, nested, key, nested_key, value)
      # auditd may duplicate keys, save timestamp before it can be overriden
      if key == MSG and value.start_with?(AUDIT)
        key = TIMESTAMP
        value.sub!(/audit\((?<g1>.*):\d{4,}\):/, '\k<g1>')
      end

      if nested
        if result[nested_key][key].nil?
          result[nested_key][key] = value
        else
          if result[nested_key][key].kind_of?(Array)
            result[nested_key][key] << value
          else
            temp = result[nested_key][key]
            result[nested_key][key] = [temp, value]
          end
        end
      else
        if result[key].nil?
          result[key] = value
        else
          if result[key].kind_of?(Array)
            result[key] << value
          else
            temp = result[key]
            result[key] = [temp, value]
          end
        end
      end
    end
  end
end