package action

_lib: slack: message?: {
	#input: string | *"Slack Message"
	#channels?: [...string]
	#user?: string
	#msg?:  string
}

let cfg = _lib.slack.message

if cfg != _|_ {
	inputs: "\(cfg.#input)": match: cfg & {
	}
}
