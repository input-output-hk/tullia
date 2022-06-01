## _module.args : lazy attribute set of raw value
Description: Additional arguments passed to each module in addition to ones
like <literal>lib</literal>, <literal>config</literal>,
and <literal>pkgs</literal>, <literal>modulesPath</literal>.
</para>
<para>
This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument <literal>name</literal> which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.
</para>
<para>
Some arguments are already passed by default, of which the
following <emphasis>cannot</emphasis> be changed with this option:
<itemizedlist>
 <listitem>
  <para>
   <varname>lib</varname>: The nixpkgs library.
  </para>
 </listitem>
 <listitem>
  <para>
   <varname>config</varname>: The results of all options after merging the values from all modules together.
  </para>
 </listitem>
 <listitem>
  <para>
   <varname>options</varname>: The options declared in all modules.
  </para>
 </listitem>
 <listitem>
  <para>
   <varname>specialArgs</varname>: The <literal>specialArgs</literal> argument passed to <literal>evalModules</literal>.
  </para>
 </listitem>
 <listitem>
  <para>
   All attributes of <varname>specialArgs</varname>
  </para>
  <para>
   Whereas option values can generally depend on other option values
   thanks to laziness, this does not apply to <literal>imports</literal>, which
   must be computed statically before anything else.
  </para>
  <para>
   For this reason, callers of the module system can provide <literal>specialArgs</literal>
   which are available during import resolution.
  </para>
  <para>
   For NixOS, <literal>specialArgs</literal> includes
   <varname>modulesPath</varname>, which allows you to import
   extra modules from the nixpkgs package tree without having to
   somehow make the module aware of the location of the
   <literal>nixpkgs</literal> or NixOS directories.
<programlisting>
{ modulesPath, ... }: {
  imports = [
    (modulesPath + "/profiles/minimal.nix")
  ];
}
</programlisting>
  </para>
 </listitem>
</itemizedlist>
</para>
<para>
For NixOS, the default value for this option includes at least this argument:
<itemizedlist>
 <listitem>
  <para>
   <varname>pkgs</varname>: The nixpkgs package set according to
   the <option>nixpkgs.pkgs</option> option.
  </para>
 </listitem>
</itemizedlist>

## action : attribute set of submodule
Default: `{}`
Description: A Cicero action

## action.<name>.io : path
Description: Path to a CUE file specifying the inputs/outputs of the Cicero action.

## action.<name>.job : attribute set of submodule
Default: `{}`
Description: The Nomad job generated from the task.

## action.<name>.job.<name>.datacenters : list of string
Default: `["dc1"]`
Description: Which datacenters the Nomad job should be scheduled in.

## action.<name>.job.<name>.group : attribute set of submodule
Default: `{}`
Description: The Nomad Task Group

## action.<name>.job.<name>.group.<name>.reschedule : attribute set of anything
Default: `{}`
Description: Nomad reschedule stanza

## action.<name>.job.<name>.group.<name>.restart : attribute set of anything
Default: `{}`
Description: Nomad restart stanza

## action.<name>.job.<name>.group.<name>.task : attribute set of anything
Default: `{}`
Description: Nomad job stanza

## action.<name>.job.<name>.namespace : string
Default: `"default"`
Description: Namespace the Nomad job should run in.

## action.<name>.job.<name>.type : one of "batch", "service", "batch", "sysbatch"
Default: `"batch"`
Description: The Nomad job type

## action.<name>.prepare : anything
Default: `[]`
Description: Information required by Cicero to push images.

## action.<name>.task : null or string
Default: `null`
Description: Name of the Tullia task to execute

## dag : attribute set of anything
Default: `{}`
Description: Information for the Tullia execution

## job : attribute set of submodule
Default: `{}`
Description: A Nomad job

## job.<name>.datacenters : list of string
Default: `["dc1"]`
Description: Which datacenters the Nomad job should be scheduled in.

## job.<name>.group : attribute set of submodule
Default: `{}`
Description: The Nomad Task Group

## job.<name>.group.<name>.reschedule : attribute set of anything
Default: `{}`
Description: Nomad reschedule stanza

## job.<name>.group.<name>.restart : attribute set of anything
Default: `{}`
Description: Nomad restart stanza

## job.<name>.group.<name>.task : attribute set of anything
Default: `{}`
Description: Nomad job stanza

## job.<name>.namespace : string
Default: `"default"`
Description: Namespace the Nomad job should run in.

## job.<name>.type : one of "batch", "service", "batch", "sysbatch"
Default: `"batch"`
Description: The Nomad job type

## task : attribute set of submodule
Default: `{}`
Description: A Tullia task

## task.<name>.enable : boolean
Default: `true`
Description: Whether to enable the task.
Example: `true`

## task.<name>.action : submodule
Default: `{}`
Description: Information provided by Cicero while executing an action.

## task.<name>.action.facts : attribute set of submodule
Default: `{}`
Description: Facts that matched the io.

## task.<name>.action.facts.<name>.binary_hash : string
Description: Binary hash of the fact

## task.<name>.action.facts.<name>.id : string
Description: ID of the fact

## task.<name>.action.facts.<name>.name : string
Default: `"‹name›"`
Description: Name of the fact

## task.<name>.action.facts.<name>.value : attribute set of anything
Description: Value of the fact

## task.<name>.action.id : string
Description: ID of the Cicero run

## task.<name>.action.name : string
Description: Name of the Cicero action

## task.<name>.after : list of string
Default: `[]`
Description: Name of Tullia tasks to run after this one.

## task.<name>.command : submodule
Default: `{text = ""}`
Description: Command to execute

## task.<name>.command.check : boolean
Default: `true`
Description: Check syntax of the command

## task.<name>.command.runtimeInputs : list of package
Default: `[{drvPath = "coreutils-9.0"; name = "coreutils-9.0"; outPath = "coreutils-9.0"; type = "derivation"}, {drvPath = "bash-interactive-5.1-p16"; name = "bash-interactive-5.1-p16"; outPath = "bash-interactive-5.1-p16"; type = "derivation"}]`
Description: Dependencies of the command (defaults to task.dependencies)

## task.<name>.command.text : string or path
Description: Type of the command

## task.<name>.command.type : one of "elvish", "ruby", "shell"
Default: `"shell"`
Description: Type of the command

## task.<name>.commands : list of submodule
Description: Combines the command with any others defined by presets.

## task.<name>.commands.*.check : boolean
Default: `true`
Description: Check syntax of the command

## task.<name>.commands.*.runtimeInputs : list of package
Default: `[{drvPath = "coreutils-9.0"; name = "coreutils-9.0"; outPath = "coreutils-9.0"; type = "derivation"}, {drvPath = "bash-interactive-5.1-p16"; name = "bash-interactive-5.1-p16"; outPath = "bash-interactive-5.1-p16"; type = "derivation"}]`
Description: Dependencies of the command (defaults to task.dependencies)

## task.<name>.commands.*.text : string or path
Description: Type of the command

## task.<name>.commands.*.type : one of "elvish", "ruby", "shell"
Default: `"shell"`
Description: Type of the command

## task.<name>.dependencies : list of package
Default: `[]`
Description: Dependencies used by the command

## task.<name>.env : attribute set of string
Default: `{SSL_CERT_FILE = "/nix/store/6522l96q7d6yk848w5nr3gim901qysf6-nss-cacert-3.77/etc/ssl/certs/ca-bundle.crt"}`
Description: Some description of `env`

## task.<name>.memory : unsigned integer, meaning >=0
Default: `300`

## task.<name>.name : string
Default: `"‹name›"`

## task.<name>.nomad : submodule
Default: `{}`

## task.<name>.nomad.config : attribute set of anything
Default: `{}`

## task.<name>.nomad.driver : one of "exec", "nix", "docker", "podman", "java"
Default: `"podman"`

## task.<name>.nomad.env : attribute set of string
Default: `{}`

## task.<name>.nomad.meta : attribute set of string
Default: `{}`

## task.<name>.nomad.resources : submodule
Default: `{}`

## task.<name>.nomad.resources.cores : null or positive integer, meaning >0
Default: `null`

## task.<name>.nomad.resources.cpu : positive integer, meaning >0
Default: `100`

## task.<name>.nomad.resources.memory : positive integer, meaning >0
Default: `300`

## task.<name>.nomad.service : attribute set of anything
Default: `{}`

## task.<name>.nsjail : submodule
Default: `{}`

## task.<name>.nsjail.bindmount : submodule
Default: `{}`

## task.<name>.nsjail.bindmount.ro : list of string
Default: `[]`

## task.<name>.nsjail.bindmount.rw : list of string
Default: `[]`

## task.<name>.nsjail.cgroup : submodule
Default: `{}`

## task.<name>.nsjail.cgroup.cpuMsPerSec : unsigned integer, meaning >=0
Default: `0`
Description: Number of milliseconds of CPU time per second that the process group can use. 0 is disabled

## task.<name>.nsjail.cgroup.memMax : unsigned integer, meaning >=0
Default: `314572800`
Description: Maximum number of bytes to use in the group. 0 is disabled

## task.<name>.nsjail.cgroup.netClsClassid : unsigned integer, meaning >=0
Default: `0`
Description: Class identifier of network packets in the group. 0 is disabled

## task.<name>.nsjail.cgroup.pidsMax : unsigned integer, meaning >=0
Default: `0`
Description: Maximum number of pids in a cgroup. 0 is disabled

## task.<name>.nsjail.cloneNewnet : boolean
Default: `false`

## task.<name>.nsjail.cwd : string
Default: `"/repo"`
Description: change to this directory before starting the script startup

## task.<name>.nsjail.mount : attribute set of submodule
Default: `{}`

## task.<name>.nsjail.mount.<name>.from : string
Default: `"none"`

## task.<name>.nsjail.mount.<name>.options : attribute set of anything


## task.<name>.nsjail.mount.<name>.to : string
Default: `"‹name›"`

## task.<name>.nsjail.mount.<name>.type : value "tmpfs" (singular enum)
Default: `"tmpfs"`

## task.<name>.nsjail.quiet : boolean
Default: `true`

## task.<name>.nsjail.rlimit : submodule
Default: `{}`

## task.<name>.nsjail.rlimit.as : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"max"`
Description: virtual memory size limit in MB

## task.<name>.nsjail.rlimit.core : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"max"`
Description: CPU time in seconds

## task.<name>.nsjail.rlimit.cpu : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"max"`
Description: CPU time in seconds

## task.<name>.nsjail.rlimit.fsize : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"max"`
Description: Maximum file size.

## task.<name>.nsjail.rlimit.nofile : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"max"`
Description: Maximum number of open files.

## task.<name>.nsjail.rlimit.nproc : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"soft"`
Description: Maximum number of processes.

## task.<name>.nsjail.rlimit.stack : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"inf"`
Description: Maximum size of the stack.

## task.<name>.nsjail.run : package
Default: `{drvPath = "-name--nsjail"; name = "-name--nsjail"; outPath = "-name--nsjail"; type = "derivation"}`
Description: Execute the task in a nsjail sandbox

## task.<name>.nsjail.setsid : boolean
Default: `true`
Description: setsid runs a program in a new session.
Disabling this allows for terminal signal handling in the
sandboxed process which may be dangerous.

## task.<name>.nsjail.timeLimit : unsigned integer, meaning >=0
Default: `30`

## task.<name>.nsjail.verbose : boolean
Default: `false`

## task.<name>.oci : submodule
Default: `{}`

## task.<name>.oci.cmd : list of string
Default: `[]`
Description: Default arguments to the entrypoint of the
container. These values act as defaults and may
be replaced by any specified when creating a
container. If an Entrypoint value is not
specified, then the first entry of the Cmd array
SHOULD be interpreted as the executable to run.

## task.<name>.oci.config : submodule
Default: `{}`

## task.<name>.oci.config.Cmd : list of string
Default: `["/nix/store/jfllr835ps0c04kjz0cyqjp96g5k7k4c--name-/bin/‹name›"]`
Description: Default arguments to the entrypoint of the
container. These values act as defaults and may
be replaced by any specified when creating a
container. If an Entrypoint value is not
specified, then the first entry of the Cmd array
SHOULD be interpreted as the executable to run.

## task.<name>.oci.config.Entrypoint : list of string
Default: `[]`
Description: A list of arguments to use as the command to
execute when the container starts. These values
act as defaults and may be replaced by an
entrypoint specified when creating a container.

## task.<name>.oci.config.Env : list of string
Default: `["CURL_CA_BUNDLE=/nix/store/6522l96q7d6yk848w5nr3gim901qysf6-nss-cacert-3.77/etc/ssl/certs/ca-bundle.crt", "HOME=/local", "NIX_SSL_CERT_FILE=/nix/store/6522l96q7d6yk848w5nr3gim901qysf6-nss-cacert-3.77/etc/ssl/certs/ca-bundle.crt", "SSL_CERT_FILE=/nix/store/6522l96q7d6yk848w5nr3gim901qysf6-nss-cacert-3.77/etc/ssl/certs/ca-bundle.crt", "TERM=xterm-256color", "TULLIA_TASK=‹name›"]`
Description: Entries are in the format of VARNAME=VARVALUE.
These values act as defaults and are merged with
any specified when creating a container.

## task.<name>.oci.config.ExposedPorts : attribute set of attribute set
Default: `{}`
Description: A set of ports to expose from a container running
this image. Its keys can be in the format of:
port/tcp, port/udp, port with the default
protocol being tcp if not specified. These values
act as defaults and are merged with any specified
when creating a container.
NOTE: This JSON structure value is unusual
because it is a direct JSON serialization of the
Go type map[string]struct{} and is represented in
JSON as an object mapping its keys to an empty
object.
For this config, we filter out all keys with
false values.

## task.<name>.oci.config.Labels : attribute set of string
Default: `{}`
Description: The field contains arbitrary metadata for the container.
This property MUST use the annotation rules.
https://github.com/opencontainers/image-spec/blob/main/annotations.md#rules

## task.<name>.oci.config.StopSignal : string
Default: `""`
Description: The field contains the system call signal that will be
sent to the container to exit. The signal can be a signal
name in the format SIGNAME, for instance SIGKILL or
SIGRTMIN+3.

## task.<name>.oci.config.User : string
Default: `""`
Description: The username or UID which is a platform-specific
structure that allows specific control over which
user the process run as. This acts as a default
value to use when the value is not specified when
creating a container. For Linux based systems,
all of the following are valid: user, uid,
user:group, uid:gid, uid:group, user:gid. If
group/gid is not specified, the default group and
supplementary groups of the given user/uid in
/etc/passwd from the container are applied.

## task.<name>.oci.config.Volumes : attribute set of attribute set
Default: `{/local = {}; /tmp = {}}`
Description: A set of directories describing where the
process is likely to write data specific to a
container instance. NOTE: This JSON structure
value is unusual because it is a direct JSON
serialization of the Go type
map[string]struct{} and is represented in JSON
as an object mapping its keys to an empty
object.

## task.<name>.oci.config.WorkingDir : string
Default: `"/repo"`
Description: Sets the current working directory of the entrypoint
process in the container. This value acts as a default
and may be replaced by a working directory specified when
creating a container.

## task.<name>.oci.contents : list of package
Description: A list of store paths to include in the layer root. The store
path prefix /nix/store/hash-path is removed. The store path
content is then located at the image /.

## task.<name>.oci.entrypoint : list of string
Default: `[]`
Description: A list of arguments to use as the command to
execute when the container starts. These values
act as defaults and may be replaced by an
entrypoint specified when creating a container.

## task.<name>.oci.env : attribute set of string
Default: `{}`
Description: Entries are in the format of VARNAME=VARVALUE.
These values act as defaults and are merged with
any specified when creating a container.

## task.<name>.oci.exposedPorts : attribute set of boolean
Default: `{}`
Description: A set of ports to expose from a container running
this image. Its keys can be in the format of:
port/tcp, port/udp, port with the default
protocol being tcp if not specified. These values
act as defaults and are merged with any specified
when creating a container.
NOTE: This JSON structure value is unusual
because it is a direct JSON serialization of the
Go type map[string]struct{} and is represented in
JSON as an object mapping its keys to an empty
object.
For this config, we filter out all keys with
false values.

## task.<name>.oci.fromImage : string
Default: `""`
Description: An image that is used as the base image of this image.

## task.<name>.oci.image : package
Default: `{drvPath = "image--name-.json"; name = "image--name-.json"; outPath = "image--name-.json"; type = "derivation"}`

## task.<name>.oci.labels : attribute set of string
Default: `{}`
Description: The field contains arbitrary metadata for the container.
This property MUST use the annotation rules.
https://github.com/opencontainers/image-spec/blob/main/annotations.md#rules

## task.<name>.oci.layers : list of package
Default: `[]`
Description: A list of layers built with the buildLayer function: if a store
path in deps or contents belongs to one of these layers, this
store path is skipped. This is pretty useful to isolate store
paths that are often updated from more stable store paths, to
speed up build and push time.

## task.<name>.oci.maxLayers : positive integer, meaning >0
Default: `30`
Description: The maximun number of layer to create. This is based on the
store path "popularity" as described in
https://grahamc.com/blog/nix-and-layered-docker-images Note
this is applied on the image layers and not on layers added
with the buildImage.layers attribute

## task.<name>.oci.name : string
Default: `"localhost/‹name›"`

## task.<name>.oci.perms : list of submodule
Default: `[]`

## task.<name>.oci.perms.*.mode : string
Example: `"0664"`

## task.<name>.oci.perms.*.path : string
Description: a store path

## task.<name>.oci.perms.*.regex : string
Example: `".*"`

## task.<name>.oci.stopSignal : string
Default: `""`
Description: The field contains the system call signal that will be
sent to the container to exit. The signal can be a signal
name in the format SIGNAME, for instance SIGKILL or
SIGRTMIN+3.

## task.<name>.oci.tag : null or string
Default: `null`

## task.<name>.oci.user : string
Default: `""`
Description: The username or UID which is a platform-specific
structure that allows specific control over which
user the process run as. This acts as a default
value to use when the value is not specified when
creating a container. For Linux based systems,
all of the following are valid: user, uid,
user:group, uid:gid, uid:group, user:gid. If
group/gid is not specified, the default group and
supplementary groups of the given user/uid in
/etc/passwd from the container are applied.

## task.<name>.oci.volumes : attribute set of anything
Default: `{}`
Description: A set of directories describing where the
process is likely to write data specific to a
container instance. NOTE: This JSON structure
value is unusual because it is a direct JSON
serialization of the Go type
map[string]struct{} and is represented in JSON
as an object mapping its keys to an empty
object.

## task.<name>.oci.workingDir : string
Default: `"/repo"`
Description: Sets the current working directory of the entrypoint
process in the container. This value acts as a default
and may be replaced by a working directory specified when
creating a container.

## task.<name>.podman : submodule
Default: `{}`

## task.<name>.podman.run : package
Default: `{drvPath = "-name--podman"; name = "-name--podman"; outPath = "-name--podman"; type = "derivation"}`
Description: Copy the task to local podman and execute it

## task.<name>.podman.useHostStore : boolean
Default: `true`

## task.<name>.preset.bash.enable : boolean
Default: `false`
Description: Whether to enable bash preset.
Example: `true`

## task.<name>.preset.github-ci.enable : boolean
Default: `false`
Description: Whether to enable github-ci preset.
Example: `true`

## task.<name>.preset.github-ci.repo : string
Description: Path of the respository (the part after `github.com/`).
Example: `"input-output-hk/tullia"`

## task.<name>.preset.github-ci.sha : string
Description: The Revision (SHA) of the commit to clone and report status on.
Example: `"841342ce5a67acd93a78e5b1a56e6bbe92db926f"`

## task.<name>.preset.nix.enable : boolean
Default: `false`
Description: Whether to enable nix preset.
Example: `true`

## task.<name>.run : package
Default: `{drvPath = "-name--nsjail"; name = "-name--nsjail"; outPath = "-name--nsjail"; type = "derivation"}`
Description: Depending on the `runtime` option, this is a shortcut to `task.<name>.<runtime>.run`.

## task.<name>.runtime : one of "nsjail", "podman", "unwrapped"
Default: `"nsjail"`
Description: The runtime determines how tullia executes the task. This directly
maps to the attribute `task.<name>.<runtime>.run` that is able to be
executed using `nix run`.

## task.<name>.unwrapped : submodule
Default: `{}`
Description: Run the task without any container, useful for nested executions of
Tullia.

## task.<name>.unwrapped.run : package
Default: `{drvPath = "-name--unwrapped"; name = "-name--unwrapped"; outPath = "-name--unwrapped"; type = "derivation"}`
Description: Run the task without any container.

## task.<name>.workingDir : string
Default: `"/repo"`
Description: The directory that the task will be executed in.
This defaults to /repo and the source is available there using a
bindmount when run locally, or cloned when remotely.

## wrappedTask : attribute set of submodule
Default: `{}`
Description: A Tullia task wrapped in the tullia process to also execute its dependencies.

## wrappedTask.<name>.enable : boolean
Default: `true`
Description: Whether to enable the task.
Example: `true`

## wrappedTask.<name>.action : submodule
Default: `{}`
Description: Information provided by Cicero while executing an action.

## wrappedTask.<name>.action.facts : attribute set of submodule
Default: `{}`
Description: Facts that matched the io.

## wrappedTask.<name>.action.facts.<name>.binary_hash : string
Description: Binary hash of the fact

## wrappedTask.<name>.action.facts.<name>.id : string
Description: ID of the fact

## wrappedTask.<name>.action.facts.<name>.name : string
Default: `"‹name›"`
Description: Name of the fact

## wrappedTask.<name>.action.facts.<name>.value : attribute set of anything
Description: Value of the fact

## wrappedTask.<name>.action.id : string
Description: ID of the Cicero run

## wrappedTask.<name>.action.name : string
Description: Name of the Cicero action

## wrappedTask.<name>.after : list of string
Default: `[]`
Description: Name of Tullia tasks to run after this one.

## wrappedTask.<name>.command : submodule
Default: `{text = ""}`
Description: Command to execute

## wrappedTask.<name>.command.check : boolean
Default: `true`
Description: Check syntax of the command

## wrappedTask.<name>.command.runtimeInputs : list of package
Default: `[{drvPath = "coreutils-9.0"; name = "coreutils-9.0"; outPath = "coreutils-9.0"; type = "derivation"}, {drvPath = "bash-interactive-5.1-p16"; name = "bash-interactive-5.1-p16"; outPath = "bash-interactive-5.1-p16"; type = "derivation"}]`
Description: Dependencies of the command (defaults to task.dependencies)

## wrappedTask.<name>.command.text : string or path
Description: Type of the command

## wrappedTask.<name>.command.type : one of "elvish", "ruby", "shell"
Default: `"shell"`
Description: Type of the command

## wrappedTask.<name>.commands : list of submodule
Description: Combines the command with any others defined by presets.

## wrappedTask.<name>.commands.*.check : boolean
Default: `true`
Description: Check syntax of the command

## wrappedTask.<name>.commands.*.runtimeInputs : list of package
Default: `[{drvPath = "coreutils-9.0"; name = "coreutils-9.0"; outPath = "coreutils-9.0"; type = "derivation"}, {drvPath = "bash-interactive-5.1-p16"; name = "bash-interactive-5.1-p16"; outPath = "bash-interactive-5.1-p16"; type = "derivation"}]`
Description: Dependencies of the command (defaults to task.dependencies)

## wrappedTask.<name>.commands.*.text : string or path
Description: Type of the command

## wrappedTask.<name>.commands.*.type : one of "elvish", "ruby", "shell"
Default: `"shell"`
Description: Type of the command

## wrappedTask.<name>.dependencies : list of package
Default: `[]`
Description: Dependencies used by the command

## wrappedTask.<name>.env : attribute set of string
Default: `{SSL_CERT_FILE = "/nix/store/6522l96q7d6yk848w5nr3gim901qysf6-nss-cacert-3.77/etc/ssl/certs/ca-bundle.crt"}`
Description: Some description of `env`

## wrappedTask.<name>.memory : unsigned integer, meaning >=0
Default: `300`

## wrappedTask.<name>.name : string
Default: `"‹name›"`

## wrappedTask.<name>.nomad : submodule
Default: `{}`

## wrappedTask.<name>.nomad.config : attribute set of anything
Default: `{}`

## wrappedTask.<name>.nomad.driver : one of "exec", "nix", "docker", "podman", "java"
Default: `"podman"`

## wrappedTask.<name>.nomad.env : attribute set of string
Default: `{}`

## wrappedTask.<name>.nomad.meta : attribute set of string
Default: `{}`

## wrappedTask.<name>.nomad.resources : submodule
Default: `{}`

## wrappedTask.<name>.nomad.resources.cores : null or positive integer, meaning >0
Default: `null`

## wrappedTask.<name>.nomad.resources.cpu : positive integer, meaning >0
Default: `100`

## wrappedTask.<name>.nomad.resources.memory : positive integer, meaning >0
Default: `300`

## wrappedTask.<name>.nomad.service : attribute set of anything
Default: `{}`

## wrappedTask.<name>.nsjail : submodule
Default: `{}`

## wrappedTask.<name>.nsjail.bindmount : submodule
Default: `{}`

## wrappedTask.<name>.nsjail.bindmount.ro : list of string
Default: `[]`

## wrappedTask.<name>.nsjail.bindmount.rw : list of string
Default: `[]`

## wrappedTask.<name>.nsjail.cgroup : submodule
Default: `{}`

## wrappedTask.<name>.nsjail.cgroup.cpuMsPerSec : unsigned integer, meaning >=0
Default: `0`
Description: Number of milliseconds of CPU time per second that the process group can use. 0 is disabled

## wrappedTask.<name>.nsjail.cgroup.memMax : unsigned integer, meaning >=0
Default: `314572800`
Description: Maximum number of bytes to use in the group. 0 is disabled

## wrappedTask.<name>.nsjail.cgroup.netClsClassid : unsigned integer, meaning >=0
Default: `0`
Description: Class identifier of network packets in the group. 0 is disabled

## wrappedTask.<name>.nsjail.cgroup.pidsMax : unsigned integer, meaning >=0
Default: `0`
Description: Maximum number of pids in a cgroup. 0 is disabled

## wrappedTask.<name>.nsjail.cloneNewnet : boolean
Default: `false`

## wrappedTask.<name>.nsjail.cwd : string
Default: `"/repo"`
Description: change to this directory before starting the script startup

## wrappedTask.<name>.nsjail.mount : attribute set of submodule
Default: `{}`

## wrappedTask.<name>.nsjail.mount.<name>.from : string
Default: `"none"`

## wrappedTask.<name>.nsjail.mount.<name>.options : attribute set of anything


## wrappedTask.<name>.nsjail.mount.<name>.to : string
Default: `"‹name›"`

## wrappedTask.<name>.nsjail.mount.<name>.type : value "tmpfs" (singular enum)
Default: `"tmpfs"`

## wrappedTask.<name>.nsjail.quiet : boolean
Default: `true`

## wrappedTask.<name>.nsjail.rlimit : submodule
Default: `{}`

## wrappedTask.<name>.nsjail.rlimit.as : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"max"`
Description: virtual memory size limit in MB

## wrappedTask.<name>.nsjail.rlimit.core : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"max"`
Description: CPU time in seconds

## wrappedTask.<name>.nsjail.rlimit.cpu : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"max"`
Description: CPU time in seconds

## wrappedTask.<name>.nsjail.rlimit.fsize : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"max"`
Description: Maximum file size.

## wrappedTask.<name>.nsjail.rlimit.nofile : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"max"`
Description: Maximum number of open files.

## wrappedTask.<name>.nsjail.rlimit.nproc : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"soft"`
Description: Maximum number of processes.

## wrappedTask.<name>.nsjail.rlimit.stack : one of "max", "hard", "def", "soft", "inf" or unsigned integer, meaning >=0
Default: `"inf"`
Description: Maximum size of the stack.

## wrappedTask.<name>.nsjail.run : package
Default: `{drvPath = "-name--nsjail"; name = "-name--nsjail"; outPath = "-name--nsjail"; type = "derivation"}`
Description: Execute the task in a nsjail sandbox

## wrappedTask.<name>.nsjail.setsid : boolean
Default: `true`
Description: setsid runs a program in a new session.
Disabling this allows for terminal signal handling in the
sandboxed process which may be dangerous.

## wrappedTask.<name>.nsjail.timeLimit : unsigned integer, meaning >=0
Default: `30`

## wrappedTask.<name>.nsjail.verbose : boolean
Default: `false`

## wrappedTask.<name>.oci : submodule
Default: `{}`

## wrappedTask.<name>.oci.cmd : list of string
Default: `[]`
Description: Default arguments to the entrypoint of the
container. These values act as defaults and may
be replaced by any specified when creating a
container. If an Entrypoint value is not
specified, then the first entry of the Cmd array
SHOULD be interpreted as the executable to run.

## wrappedTask.<name>.oci.config : submodule
Default: `{}`

## wrappedTask.<name>.oci.config.Cmd : list of string
Default: `["/nix/store/jfllr835ps0c04kjz0cyqjp96g5k7k4c--name-/bin/‹name›"]`
Description: Default arguments to the entrypoint of the
container. These values act as defaults and may
be replaced by any specified when creating a
container. If an Entrypoint value is not
specified, then the first entry of the Cmd array
SHOULD be interpreted as the executable to run.

## wrappedTask.<name>.oci.config.Entrypoint : list of string
Default: `[]`
Description: A list of arguments to use as the command to
execute when the container starts. These values
act as defaults and may be replaced by an
entrypoint specified when creating a container.

## wrappedTask.<name>.oci.config.Env : list of string
Default: `["CURL_CA_BUNDLE=/nix/store/6522l96q7d6yk848w5nr3gim901qysf6-nss-cacert-3.77/etc/ssl/certs/ca-bundle.crt", "HOME=/local", "NIX_SSL_CERT_FILE=/nix/store/6522l96q7d6yk848w5nr3gim901qysf6-nss-cacert-3.77/etc/ssl/certs/ca-bundle.crt", "SSL_CERT_FILE=/nix/store/6522l96q7d6yk848w5nr3gim901qysf6-nss-cacert-3.77/etc/ssl/certs/ca-bundle.crt", "TERM=xterm-256color", "TULLIA_TASK=‹name›"]`
Description: Entries are in the format of VARNAME=VARVALUE.
These values act as defaults and are merged with
any specified when creating a container.

## wrappedTask.<name>.oci.config.ExposedPorts : attribute set of attribute set
Default: `{}`
Description: A set of ports to expose from a container running
this image. Its keys can be in the format of:
port/tcp, port/udp, port with the default
protocol being tcp if not specified. These values
act as defaults and are merged with any specified
when creating a container.
NOTE: This JSON structure value is unusual
because it is a direct JSON serialization of the
Go type map[string]struct{} and is represented in
JSON as an object mapping its keys to an empty
object.
For this config, we filter out all keys with
false values.

## wrappedTask.<name>.oci.config.Labels : attribute set of string
Default: `{}`
Description: The field contains arbitrary metadata for the container.
This property MUST use the annotation rules.
https://github.com/opencontainers/image-spec/blob/main/annotations.md#rules

## wrappedTask.<name>.oci.config.StopSignal : string
Default: `""`
Description: The field contains the system call signal that will be
sent to the container to exit. The signal can be a signal
name in the format SIGNAME, for instance SIGKILL or
SIGRTMIN+3.

## wrappedTask.<name>.oci.config.User : string
Default: `""`
Description: The username or UID which is a platform-specific
structure that allows specific control over which
user the process run as. This acts as a default
value to use when the value is not specified when
creating a container. For Linux based systems,
all of the following are valid: user, uid,
user:group, uid:gid, uid:group, user:gid. If
group/gid is not specified, the default group and
supplementary groups of the given user/uid in
/etc/passwd from the container are applied.

## wrappedTask.<name>.oci.config.Volumes : attribute set of attribute set
Default: `{/local = {}; /tmp = {}}`
Description: A set of directories describing where the
process is likely to write data specific to a
container instance. NOTE: This JSON structure
value is unusual because it is a direct JSON
serialization of the Go type
map[string]struct{} and is represented in JSON
as an object mapping its keys to an empty
object.

## wrappedTask.<name>.oci.config.WorkingDir : string
Default: `"/repo"`
Description: Sets the current working directory of the entrypoint
process in the container. This value acts as a default
and may be replaced by a working directory specified when
creating a container.

## wrappedTask.<name>.oci.contents : list of package
Description: A list of store paths to include in the layer root. The store
path prefix /nix/store/hash-path is removed. The store path
content is then located at the image /.

## wrappedTask.<name>.oci.entrypoint : list of string
Default: `[]`
Description: A list of arguments to use as the command to
execute when the container starts. These values
act as defaults and may be replaced by an
entrypoint specified when creating a container.

## wrappedTask.<name>.oci.env : attribute set of string
Default: `{}`
Description: Entries are in the format of VARNAME=VARVALUE.
These values act as defaults and are merged with
any specified when creating a container.

## wrappedTask.<name>.oci.exposedPorts : attribute set of boolean
Default: `{}`
Description: A set of ports to expose from a container running
this image. Its keys can be in the format of:
port/tcp, port/udp, port with the default
protocol being tcp if not specified. These values
act as defaults and are merged with any specified
when creating a container.
NOTE: This JSON structure value is unusual
because it is a direct JSON serialization of the
Go type map[string]struct{} and is represented in
JSON as an object mapping its keys to an empty
object.
For this config, we filter out all keys with
false values.

## wrappedTask.<name>.oci.fromImage : string
Default: `""`
Description: An image that is used as the base image of this image.

## wrappedTask.<name>.oci.image : package
Default: `{drvPath = "image--name-.json"; name = "image--name-.json"; outPath = "image--name-.json"; type = "derivation"}`

## wrappedTask.<name>.oci.labels : attribute set of string
Default: `{}`
Description: The field contains arbitrary metadata for the container.
This property MUST use the annotation rules.
https://github.com/opencontainers/image-spec/blob/main/annotations.md#rules

## wrappedTask.<name>.oci.layers : list of package
Default: `[]`
Description: A list of layers built with the buildLayer function: if a store
path in deps or contents belongs to one of these layers, this
store path is skipped. This is pretty useful to isolate store
paths that are often updated from more stable store paths, to
speed up build and push time.

## wrappedTask.<name>.oci.maxLayers : positive integer, meaning >0
Default: `30`
Description: The maximun number of layer to create. This is based on the
store path "popularity" as described in
https://grahamc.com/blog/nix-and-layered-docker-images Note
this is applied on the image layers and not on layers added
with the buildImage.layers attribute

## wrappedTask.<name>.oci.name : string
Default: `"localhost/‹name›"`

## wrappedTask.<name>.oci.perms : list of submodule
Default: `[]`

## wrappedTask.<name>.oci.perms.*.mode : string
Example: `"0664"`

## wrappedTask.<name>.oci.perms.*.path : string
Description: a store path

## wrappedTask.<name>.oci.perms.*.regex : string
Example: `".*"`

## wrappedTask.<name>.oci.stopSignal : string
Default: `""`
Description: The field contains the system call signal that will be
sent to the container to exit. The signal can be a signal
name in the format SIGNAME, for instance SIGKILL or
SIGRTMIN+3.

## wrappedTask.<name>.oci.tag : null or string
Default: `null`

## wrappedTask.<name>.oci.user : string
Default: `""`
Description: The username or UID which is a platform-specific
structure that allows specific control over which
user the process run as. This acts as a default
value to use when the value is not specified when
creating a container. For Linux based systems,
all of the following are valid: user, uid,
user:group, uid:gid, uid:group, user:gid. If
group/gid is not specified, the default group and
supplementary groups of the given user/uid in
/etc/passwd from the container are applied.

## wrappedTask.<name>.oci.volumes : attribute set of anything
Default: `{}`
Description: A set of directories describing where the
process is likely to write data specific to a
container instance. NOTE: This JSON structure
value is unusual because it is a direct JSON
serialization of the Go type
map[string]struct{} and is represented in JSON
as an object mapping its keys to an empty
object.

## wrappedTask.<name>.oci.workingDir : string
Default: `"/repo"`
Description: Sets the current working directory of the entrypoint
process in the container. This value acts as a default
and may be replaced by a working directory specified when
creating a container.

## wrappedTask.<name>.podman : submodule
Default: `{}`

## wrappedTask.<name>.podman.run : package
Default: `{drvPath = "-name--podman"; name = "-name--podman"; outPath = "-name--podman"; type = "derivation"}`
Description: Copy the task to local podman and execute it

## wrappedTask.<name>.podman.useHostStore : boolean
Default: `true`

## wrappedTask.<name>.preset.bash.enable : boolean
Default: `false`
Description: Whether to enable bash preset.
Example: `true`

## wrappedTask.<name>.preset.github-ci.enable : boolean
Default: `false`
Description: Whether to enable github-ci preset.
Example: `true`

## wrappedTask.<name>.preset.github-ci.repo : string
Description: Path of the respository (the part after `github.com/`).
Example: `"input-output-hk/tullia"`

## wrappedTask.<name>.preset.github-ci.sha : string
Description: The Revision (SHA) of the commit to clone and report status on.
Example: `"841342ce5a67acd93a78e5b1a56e6bbe92db926f"`

## wrappedTask.<name>.preset.nix.enable : boolean
Default: `false`
Description: Whether to enable nix preset.
Example: `true`

## wrappedTask.<name>.run : package
Default: `{drvPath = "-name--nsjail"; name = "-name--nsjail"; outPath = "-name--nsjail"; type = "derivation"}`
Description: Depending on the `runtime` option, this is a shortcut to `task.<name>.<runtime>.run`.

## wrappedTask.<name>.runtime : one of "nsjail", "podman", "unwrapped"
Default: `"nsjail"`
Description: The runtime determines how tullia executes the task. This directly
maps to the attribute `task.<name>.<runtime>.run` that is able to be
executed using `nix run`.

## wrappedTask.<name>.unwrapped : submodule
Default: `{}`
Description: Run the task without any container, useful for nested executions of
Tullia.

## wrappedTask.<name>.unwrapped.run : package
Default: `{drvPath = "-name--unwrapped"; name = "-name--unwrapped"; outPath = "-name--unwrapped"; type = "derivation"}`
Description: Run the task without any container.

## wrappedTask.<name>.workingDir : string
Default: `"/repo"`
Description: The directory that the task will be executed in.
This defaults to /repo and the source is available there using a
bindmount when run locally, or cloned when remotely.
