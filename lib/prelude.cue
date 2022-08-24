import "struct"

#inputs: struct.MinFields(1) & {
	[string]: {
		match: {...}
		not?:      bool
		optional?: bool
		...
	}
}

#output: {
	success?: {...}
	failure?: {...}
}

inputs:  #inputs
output?: #output

#lib: {
	_#io: {
		inputs?: #inputs
		output?: #output
	}

	io: [string]: _#io

	merge: {
		#ios: [..._#io]

		for io in #ios {
			for k, v in io.inputs {
				inputs: "\(k)": {
					match: or([ for io2 in #ios {io2.inputs[k].match}])

					if v.not != _|_ {
						not: v.not
					}

					if v.optional != _|_ {
						optional: v.optional
					}
				}
			}

			output: {
				io
				inputs: _final_inputs
			}.output
		}
	}
}

// XXX Why does a let declaration not work here?
_final_inputs: inputs
