import "strings"

inputs: _
let final_inputs = inputs

#lib: io: {
	let #repo_full_name = =~"^[^/]+/[^/]+$"

	github_pr: {
		#input: {
			result: string | *"GitHub PR to \(#repo)\(_target)\(_target_default)"

			_target: *" against branch \(#target)" | ""

			_target_default: string
			if #target_default {
				_target_default: " against default branch"
			}
			if !#target_default {
				_target_default: ""
			}
		}.result

		#repo:           #repo_full_name
		#target?:        string
		#target_default: bool | *false

		if #target != _|_ {
			#target_default: false
		}

		inputs: "\(#input)": match: {
			github_event: "pull_request"
			github_body: {
				action: "opened" | "reopened" | "synchronize"

				repository: full_name: #repo

				pull_request: {
					if #target != _|_ {
						base: ref: =~#target
					}

					head: sha: string
				}

				repository: default_branch: string
				if #target_default {
					pull_request: base: ref: repository.default_branch
				}
			}
		}

		output: {
			success: ok: true
			failure: ok: false
			if _revision != _|_ {
				[string]: revision: _revision
			}
		}

		let body = final_inputs[#input].match.github_body
		_repo:           body.repository.full_name
		_target:         body.pull_request.base.ref
		_default_branch: body.repository.default_branch
		_revision:       body.pull_request.head.sha
	}

	github_push: {
		#input: {
			result: string | *"GitHub Push to \(#repo)\(_branch)\(_default_branch)\(_tag)"

			_branch: *" on branch \(#branch)" | ""

			_default_branch: string
			if #default_branch {
				_default_branch: " on default branch"
			}
			if !#default_branch {
				_default_branch: ""
			}

			_tag: *" on tag \(#tag)" | ""
		}.result

		#repo:           #repo_full_name
		#branch?:        string
		#tag?:           string
		#default_branch: bool | *false

		if #branch != _|_ || #tag != _|_ {
			#default_branch: false
		}

		inputs: "\(#input)": match: {
			github_event: "push"
			github_body: {
				deleted: false
				repository: full_name: #repo
				head_commit: id:       string

				ref: string
				if #branch != _|_ || #tag != _|_ {
					ref: or([
						if #branch != _|_ {
							=~"^refs/heads/(\(#branch))$"
						},
						if #tag != _|_ {
							=~"^refs/tags/(\(#tag))$"
						},
					])
				}

				repository: default_branch: string
				if #default_branch {
					ref: "refs/heads/\(repository.default_branch)"
				}
			}
		}

		output: {
			success: ok: true
			failure: ok: false
			if _revision != _|_ {
				[string]: revision: _revision
			}
		}

		let body = final_inputs[#input].match.github_body
		_repo:           body.repository.full_name
		_branch:         strings.TrimPrefix(body.ref, "refs/heads/")
		_tag:            strings.TrimPrefix(body.ref, "refs/tags/")
		_default_branch: body.repository.default_branch
		_revision:       body.head_commit.id
	}
}
