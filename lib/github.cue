_lib: github: {
	#input: string | *"GitHub event"
	#repo?: string

	pull_request?: {
		#repo: =~"^[^/]+/[^/]+$"
		if github.#repo != _|_ {
			#repo: github.#repo
		}
		#target?:        string
		#target_default: bool | *true
	}

	push?: {
		#repo: =~"^[^/]+/[^/]+$"
		if github.#repo != _|_ {
			#repo: github.#repo
		}
		#branch?:        string
		#tag?:           string
		#default_branch: bool | *true
	}
}


let cfg_pr = _lib.github.pull_request
let cfg_push = _lib.github.push

inputs: "\(_lib.github.#input)": match: "github-event": or([
	if cfg_pr != _|_ { // (indent is messed up by cue fmt)
		cfg_pr & {
			action: "opened" | "reopened" | "synchronize"

			repository: full_name: cfg_pr.#repo

			pull_request: {
				if cfg_pr.#target != _|_ {
					base: ref: cfg_pr.#target
				}

				head: sha: string
			}

			if cfg_pr.#target_default {
				pull_request: base: ref: repository.default_branch
				repository: default_branch: string
			}
		}
	},
	if cfg_push != _|_ {
		cfg_push & {
			pusher: {}
			deleted: false
			repository: full_name: cfg_push.#repo
			head_commit: id:       string

			ref: string
			if cfg_push.#branch != _|_ || cfg_push.#tag != _|_ {
				ref: or([
					if cfg_push.#branch != _|_ {
						=~"^refs/heads/\(cfg_push.#branch)$"
					},
					if cfg_push.#tag != _|_ {
						=~"^refs/tags/\(cfg_push.#tag)$"
					},
				])
			}

			if cfg_push.#default_branch {
				_lib: github: push: #branch: repository.default_branch
				repository: default_branch: string
			}
		}
	},
])

output: {
	success: ok: true

	let event = inputs[_lib.github.#input].value."github-event"

	[string]: revision:
		event.pull_request.head.sha | // PR
		event.head_commit.id // push
}
