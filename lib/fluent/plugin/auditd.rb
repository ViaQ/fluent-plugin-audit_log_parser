module Fluent
  class Auditd
    class AuditdParserException < StandardError
    end
    
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
            if nested
              result[nested_key][key] = value
            else
              result[key] = value
            end
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
              if nested
                result[nested_key][key] = value
              else
                result[key] = value
              end
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
      raise AuditdParserException sprintf "Error after processing string '%s'\nBuilt %s", line, result
    end

  end
end