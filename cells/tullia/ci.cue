 let github = {// (indent is messed up by cue fmt)
	#input: "GitHub Push or PR"
	#repo:  "input-output-hk/tullia"
}

#lib.merge
#ios: [
	{#lib.io.github_push, github, #default_branch: true},
	{#lib.io.github_pr, github},
]
