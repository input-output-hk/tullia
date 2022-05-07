package action

_lib: github: pull_request: {
	#input:  "github"
	#repo:   "input-output-hk/cicero"
	#target: "main"
	pull_request: base: repo: watchers: >10
}

_lib: slack: message: {
	#input: "slack"
	#channels: ["foo"]
}
