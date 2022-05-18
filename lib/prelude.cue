import "struct"

inputs: struct.MinFields(1) & {
	[string]: {
		match: {}
		not?:      bool
		optional?: bool
	}
}

output?: {
	success?: {}
	failure?: {}
}

_lib: [string]: {}
