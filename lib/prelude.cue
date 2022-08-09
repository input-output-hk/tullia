import "struct"

#inputs: struct.MinFields(1) & {
	[string]: {
		match: {...}
		value:     match // injected by cicero
		not?:      bool
		optional?: bool
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

	ios: [..._#io]
}

for io in #lib.ios {
	for k, v in io.inputs {
		inputs: "\(k)": {
			match: or([ for io2 in #lib.ios {io2.inputs[k].match}])

			not?: and([ for io2 in #lib.ios {io2.inputs[k].not}])
			if v.not != _|_ {
				not?: v.not
			}

			optional?: and([ for io2 in #lib.ios {io2.inputs[k].optional}])
			if v.optional != _|_ {
				optional?: v.optional
			}
		}
	}

	output: io.output
}
