r = WR_ProposalPackage.instance_variable_get(:@running)
res = WR_ProposalPackage.instance_variable_get(:@results) || []
{ 'running' => r, 'n' => res.length,
  'rows' => res.map { |h| [h[:file], h[:lane], h[:status], (h[:detail].to_s[0,90])] },
  'elapsed' => ($T3_T0 ? (Time.now - $T3_T0).round(1) : nil) }
