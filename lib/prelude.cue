import (
	"list"
	"struct"
)

#inputs: struct.MinFields(1) & {
	[string]: {
		match: {...}
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

let final_inputs = inputs

#lib: {
	_#io: {
		inputs?: #inputs
		output?: #output
	}

	io: [string]: _#io

	merge: {
		#ios: [..._#io]

		let merged = {
			// Declare these so that we can refer to them directly
			// as we cannot refer to fields of the list comprehension below.
			inputs: _
			output: _

			let input_names = list.SortStrings([ for io in #ios for k, _ in io.inputs {k}])
			let input_names_unique = [
				for i, v in input_names
				let i2 = {
					if i-1 < 0 {0}
					if i-1 >= 0 {i - 1}
				}
				if i2 != i || input_names[i2] != v {v},
			]

			for i in input_names_unique {
				inputs: "\(i)": {
					match: or([
						for io in #ios
						let input = io.inputs[i]
						if input != _|_ {input.match},
					])

					for io in #ios
					let input = io.inputs[i]
					if input != _|_
					for k, v in input
					if k != "match" {"\(k)": v}
				}
			}

			for io in #ios {
				output: {
					io
					inputs: final_inputs
				}.output
			}
		}

		// We cannot use `merged` as the top level directly
		// because its incomplete `inputs` will be checked
		// against `#inputs` due to `inputs: #inputs` above
		// during computation of the list comprehension,
		// at which point `inputs` is empty so it fails.
		inputs: merged.inputs
		output: merged.output
	}
}
