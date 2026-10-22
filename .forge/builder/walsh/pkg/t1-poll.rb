r = WR_ProposalPackage.instance_variable_get(:@running)
res = (WR_ProposalPackage.instance_variable_get(:@results) || []).map { |x| "#{x[:file]}:#{x[:status]}" }
puts "running=#{r.inspect} results=#{res.inspect}"
true
