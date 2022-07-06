import "struct"

inputs: struct.MinFields(1) & {
	[string]: {
		match: {}
		not?:      bool
		optional?: bool
	}
}

output?: close({
	success?: {}
	failure?: {}
})

_lib: [string]: {}
