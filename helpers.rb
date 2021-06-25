def extract_prefix(message)
  message.content.chr
end

def extract_cmd(message)
  message.content[1..][/(\w+)/, 0] # first word without prefix
end

def extract_params(message)
  args = message.content[message.content.index(" ")+1..] # all after first space
end