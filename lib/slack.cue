package action

_lib: slack: message: {
	#input: *null | string
	#channels?: [...string]
	#user?: string
	#msg?:  string
}

if _lib.slack.message.#input != null {
	let cfg = _lib.slack.message

	inputs: "\(cfg.#input)": cfg & {
	}
}
