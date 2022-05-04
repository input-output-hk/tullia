task: "build"

input: "tullia/ci": start: {
	clone_url:     string
	sha:           string
	statuses_url?: string

	ref?:            "refs/heads/\(default_branch)"
	default_branch?: string
}

output: success: {
	ok:             true
	revision:       start.sha
	ref:            start.ref || null
	default_branch: start.default_branch || null
}
