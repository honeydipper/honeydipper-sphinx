Essentials
**********

The essential configurations to bootstrap Honeydipper

Installation
============

Include the following section in your **init.yaml** under **repos** section

.. code-block:: yaml

   - repo: https://github.com/honeydipper/honeydipper-config-essentials
     branch: main

Drivers
=======

This repo provides following drivers

api-broadcast
-------------

This driver shares the code with `redispubsub` driver. The purpose is provide a abstract
feature for services to make broadcasts to each other. The current `redispubsub` driver
offers a few functions through a `call_driver`. Once the `DipperCL` offers `call_feature`
statement, we can consolidate the loading of the two drivers into one.


**Configurations**

:connection: The parameters used for connecting to the redis including `Addr`, `Username`, `Password` and `DB`.

:connection.TLS.Enabled: Accept true/false. Use TLS to connect to the redis server, support TLS1.2 and above.

:connection.TLS.InsecureSkipVerify: Accept true/false. Skip verifying the server certificate. If enabled, TLS is susceptible to machine-in-the-middle attacks.

:connection.TLS.VerifyServerName: When connecting using an IP instead of DNS name, you can override the name used for verifying
against the server certificate. Or, use :code:`"*"` to accept any name or certificates without
a valid common name as DNS name, no subject altertive names defined.


:connection.TLS.CACerts: A list of CA certificates used for verifying the server certificate. These certificates are added on top
of system defined CA certificates. See `Here <https://pkg.go.dev/crypto/x509#SystemCertPool>`_ for description
on where the system defined CA certificates are.


See below for an example

.. code-block:: yaml

   ---
   drivers:
     redispubsub:
       connection:
         Addr: 192.168.2.10:6379
         DB: 2
         Password: ENC[gcloud-kms,...masked]
         TLS:
           Enabled: true
           VerifyServerName: "*"
           CACerts:
             - |
               ----- BEGIN CERTIFICATE -----
               ...
               ----- END CERTIFICATE -----
   

This driver doesn't offer any actions or functions.

auth-simple
-----------

This driver provides RPCs for the API serive to authenticate the incoming requests. The
supported method includes basic authentication, and token authentication. This also acts
as a reference on how to implement authentication for honeydipper APIs.


**Configurations**

:schemes: a list of strings indicating authenticating methods to try, support `basic` and `token`.

:users: a list of users for `basic` authentication.

:users.name: the name of the user

:users.pass: the password (use encryption)

:users.subject: a structure describing the credential, used for authorization

:tokens: a map of tokens to its subjects, each subject is a structure describing
the credential, used for authorization.


See below for an example

.. code-block:: yaml

   ---
   drivers:
     auth-simple:
       schemes:
         - basic
         - token
       users:
         - name: user1
           pass: ENC[...]
           subject:
             group: engineer
             role: viewer
         - name: admin
           pass: ENC[...]
           subject:
             group: sre
             role: admin
       tokens:
         ioefui3wfjejfasf:
           subject:
             group: machine
             role: viewer
   

This driver doesn't offer any actions or functions.

kubernetes
----------

This driver enables Honeydipper to interact with kubernetes clusters including
finding and recycling deployments, running jobs and getting job logs, etc. There a few wrapper
workflows around the driver and system functions, see the workflow composing guide
for detail. This section provides information on how to configure the driver and what
the driver offers as `rawActions`, the information may be helpful for understanding
how the kubernetes workflow works.


Action: createJob
^^^^^^^^^^^^^^^^^

Start a run-to-complete job in the specified cluster. Although you can, it is not recommended to use this rawAction directly. Use the wrapper workflows instead.


**Parameters**

:type: The type of the kubernetes cluster, basically a driver that provides a RPC call for fetching the kubeconfig from. currently only `gcloud-gke` and `local` is supported, more types to be added in the future.


:source: A list of k/v pair as parameters used for making the RPC call to fetch the kubeconfig. For `local`, no value is required, the driver will try to use in-cluster configurations. For `gcloud-gke` clusters, the k/v pair should have keys including `service_account`, `project`, `zone` and `cluster`.


:namespace: The namespace for the job

:job: the job object following the kubernetes API schema

**Returns**

:metadata: The metadata for the created kubernetes job

:status: The status for the created kuberntes job

See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     call_driver: kubernetes.createJob
     with:
       type: local
       namespace: test
       job:
         apiVersion: batch/v1
         kind: Job
         metadata:
           name: pi
         spec:
           template:
             spec:
               containers:
               - name: pi
                 image: perl
                 command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
               restartPolicy: Never
           backoffLimit: 4
   

Action: recycleDeployment
^^^^^^^^^^^^^^^^^^^^^^^^^

recycle a deployment by deleting the replicaset and let it re-spawn.

**Parameters**

:type: The type of the kubernetes cluster, see **createJob** rawAction for detail


:source: A list of k/v pair as parameters used for getting kubeconfig, see **createJob** rawAction for detail


:namespace: The namespace for the deployment to be recycled, `default` if not specified

:deployment: a label selector for identifying the deployment, e.g. `run=my-app`, `app=nginx`

See below for a simple example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: alerting
           trigger: fired
       do:
         call_driver: kubernetes.recycleDeployment
         with:
           type: gcloud-gke
           source:
             service_account: ENC[gcloud-kms, ...masked... ]
             zone: us-central1-a
             project: foo
             cluster: bar
           deployment: run=my-app
   

Action: getJobLog
^^^^^^^^^^^^^^^^^

Given a kubernetes job metadata name, fetch and return all the logs for this job. Again, it is not recommended to use `createJob`, `waitForJob` or `getJobLog` directly. Use the helper workflows instead.


**Parameters**

:type: The type of the kubernetes cluster, see **createJob** rawAction for detail


:source: A list of k/v pair as parameters used for getting kubeconfig, see **createJob** rawAction for detail


:namespace: The namespace for the job

:job: The metadata name of the kubernetes job

**Returns**

:log: mapping from pod name to a map from container name to the logs

:output: with all logs concatinated

See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     run_job:
       steps:
         - call_driver: kubernetes.createJob
           with:
             type: local
             job:
               apiVersion: batch/v1
               kind: Job
               metadata:
                 name: pi
               spec:
                 template:
                   spec:
                     containers:
                     - name: pi
                       image: perl
                       command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
                     restartPolicy: Never
                 backoffLimit: 4
         - call_driver: kubernetes.waitForJob
           with:
             type: local
             job: $data.metadta.name
         - call_driver: kubernetes.getJobLog
           with:
             type: local
             job: $data.metadta.name
   

Action: waitForJob
^^^^^^^^^^^^^^^^^^

Given a kubernetes job metadata name, use watch API to watch the job until it reaches a terminal state. This action usually follows a `createJob` call and uses the previous call's output as input. Again, it is not recommended to use `createJob`, `waitForJob` or `getJobLog` directly. Use the helper workflows instead.


**Parameters**

:type: The type of the kubernetes cluster, see **createJob** rawAction for detail


:source: A list of k/v pair as parameters used for getting kubeconfig, see **createJob** rawAction for detail


:namespace: The namespace for the job

:job: The metadata name of the kubernetes job

:timeout: The timeout in seconds

**Returns**

:status: The status for the created kuberntes job

See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     run_job:
       steps:
         - call_driver: kubernetes.createJob
           with:
             type: local
             job:
               apiVersion: batch/v1
               kind: Job
               metadata:
                 name: pi
               spec:
                 template:
                   spec:
                     containers:
                     - name: pi
                       image: perl
                       command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
                     restartPolicy: Never
                 backoffLimit: 4
         - call_driver: kubernetes.waitForJob
           with:
             type: local
             job: $data.metadta.name
   

redislock
---------

redislock driver provides RPC calls for the services to acquire locks for synchronize and
coordinate between instances.


**Configurations**

:connection: The parameters used for connecting to the redis including `Addr`, `Username`, `Password` and `DB`.

:connection.TLS.Enabled: Accept true/false. Use TLS to connect to the redis server, support TLS1.2 and above.

:connection.TLS.InsecureSkipVerify: Accept true/false. Skip verifying the server certificate. If enabled, TLS is susceptible to machine-in-the-middle attacks.

:connection.TLS.VerifyServerName: When connecting using an IP instead of DNS name, you can override the name used for verifying
against the server certificate. Or, use :code:`"*"` to accept any name or certificates without
a valid common name as DNS name, no subject altertive names defined.


:connection.TLS.CACerts: A list of CA certificates used for verifying the server certificate. These certificates are added on top
of system defined CA certificates. See `Here <https://pkg.go.dev/crypto/x509#SystemCertPool>`_ for description
on where the system defined CA certificates are.


See below for an example

.. code-block:: yaml

   ---
   drivers:
     redislock:
       connection:
         Addr: 192.168.2.10:6379
         DB: 2
         Password: ENC[gcloud-kms,...masked]
         TLS:
           Enabled: true
           VerifyServerName: "*"
           CACerts:
             - |
               ----- BEGIN CERTIFICATE -----
               ...
               ----- END CERTIFICATE -----
   

This drive doesn't offer any raw actions as of now.

redispubsub
-----------

redispubsub driver is used internally to facilitate communications between
different components of Honeydipper system.


**Configurations**

:connection: The parameters used for connecting to the redis including `Addr`, `Username`, `Password` and `DB`.

:connection.TLS.Enabled: Accept true/false. Use TLS to connect to the redis server, support TLS1.2 and above.

:connection.TLS.InsecureSkipVerify: Accept true/false. Skip verifying the server certificate. If enabled, TLS is susceptible to machine-in-the-middle attacks.

:connection.TLS.VerifyServerName: When connecting using an IP instead of DNS name, you can override the name used for verifying
against the server certificate. Or, use :code:`"*"` to accept any name or certificates without
a valid common name as DNS name, no subject altertive names defined.


:connection.TLS.CACerts: A list of CA certificates used for verifying the server certificate. These certificates are added on top
of system defined CA certificates. See `Here <https://pkg.go.dev/crypto/x509#SystemCertPool>`_ for description
on where the system defined CA certificates are.


See below for an example

.. code-block:: yaml

   ---
   drivers:
     redispubsub:
       connection:
         Addr: 192.168.2.10:6379
         DB: 2
         Password: ENC[gcloud-kms,...masked]
         TLS:
           Enabled: true
           VerifyServerName: "*"
           CACerts:
             - |
               ----- BEGIN CERTIFICATE -----
               ...
               ----- END CERTIFICATE -----
   

Action: send
^^^^^^^^^^^^

broadcasting a dipper message to all Honeydipper services. This is used
in triggering configuration reloading and waking up a suspended workflow.
The payload of rawAction call will used as broadcasting dipper message
paylod.


**Parameters**

:broadcastSubject: the subject field of the dipper message to be sent

Below is an example of using the driver to trigger a configuration reload

.. code-block:: yaml

   ---
   workflows:
     reload:
       call_driver: redispubsub.send
       with:
         broadcastSubject: reload
         force: $?ctx.force
   

Below is another example of using the driver to wake up a suspended workflow

.. code-block:: yaml

   ---
   workflows:
     resume_workflow:
       call_driver: redispubsub.send
       with:
         broadcastSubject: resume_session
         key: $ctx.resume_token
         labels:
           status: $ctx.labels_status
           reason: $?ctx.labels_reason
         payload: $?ctx.resume_payload
   

redisqueue
----------

redisqueue driver is used internally to facilitate communications between
different components of Honeydipper system. It doesn't offer `rawActions` or
`rawEvents` for workflow composing.


**Configurations**

:connection: The parameters used for connecting to the redis including `Addr`, `Username`, `Password` and `DB`.

:connection.TLS.Enabled: Accept true/false. Use TLS to connect to the redis server, support TLS1.2 and above.

:connection.TLS.InsecureSkipVerify: Accept true/false. Skip verifying the server certificate. If enabled, TLS is susceptible to machine-in-the-middle attacks.

:connection.TLS.VerifyServerName: When connecting using an IP instead of DNS name, you can override the name used for verifying
against the server certificate. Or, use :code:`"*"` to accept any name or certificates without
a valid common name as DNS name, no subject altertive names defined.


:connection.TLS.CACerts: A list of CA certificates used for verifying the server certificate. These certificates are added on top
of system defined CA certificates. See `Here <https://pkg.go.dev/crypto/x509#SystemCertPool>`_ for description
on where the system defined CA certificates are.


See below for an example

.. code-block:: yaml

   ---
   drivers:
     redisqueue:
       connection:
         Addr: 192.168.2.10:6379
         DB: 2
         Password: ENC[gcloud-kms,...masked]
         TLS:
           Enabled: true
           VerifyServerName: "*"
           CACerts:
             - |
               ----- BEGIN CERTIFICATE -----
               ...
               ----- END CERTIFICATE -----
   

web
---

This driver enables Honeydipper to make outbound web requests

Action: request
^^^^^^^^^^^^^^^

making an outbound web request

**Parameters**

:URL: The target url for the outbound web request

:header: A list of k/v pair as headers for the web request

:method: The method for the web request

:content: Form data, post data or the data structure encoded as json for application/json content-type

**Returns**

:status_code: HTTP status code

:cookies: A list of k/v pair as cookies received from the web server

:headers: A list of k/v pair as headers received from the web server

:body: a string contains all response body

:json: if the return is json content type, this will be parsed json data blob

See below for a simple example

.. code-block:: yaml

   workflows:
     sending_request:
       call_driver: web.request
       with:
         URL: https://ifconfig.co
   

Below is an example of specifying header for the outbound request defined through a system function

.. code-block:: yaml

   systems:
     my_api_server:
       data:
         token: ENC[gcloud-kms,...masked...]
         url: https://foo.bar/api
       function:
         secured_api:
           driver: web
           parameters:
             URL: $sysData.url
             header:
               Authorization: Bearer {{ .sysData.token }}
               content-type: application.json
           rawAction: request
   

webhook
-------

This driver enables Honeydipper to receive incoming webhooks to trigger workflows

**Configurations**

:Addr: the address and port the webhook server is listening to

for example

.. code-block:: yaml

   ---
   drivers:
     webhook:
       Addr: :8080 # listening on all IPs at port 8080
   

Event: <default>
^^^^^^^^^^^^^^^^^

receiving an incoming webhook

**Returns**

:url: the path portion of the url for the incoming webhook request

:method: The method for the web request

:form: a list of k/v pair as query parameters from url parameter or posted form

:headers: A list of k/v pair as headers received from the request

:host: The host part of the url or the Host header

:remoteAddr: The client IP address and port in the form of `xx.xx.xx.xx:xxxx`

:json: if the content type is application/json, it will be parsed and stored in here

The returns can also be used in matching conditions

See below for a simple example

.. code-block:: yaml

   rules:
   - do:
       call_workflow: foobar
     when:
       driver: webhook
       if_match:
         form:
           s: hello
         headers:
           content-type: application/x-www-form-urlencoded
         method: POST
         url: /foo/bar
   

Below is an example of defining and using a system trigger with webhook driver

.. code-block:: yaml

   systems:
     internal:
       data:
         token: ENC[gcloud-kms,...masked...]
       trigger:
         webhook:
           driver: webhook
           if_match:
             headers:
               Authorization: Bearer {{ .sysData.token }}
             remoteAddr: :regex:^10\.
   rules:
     - when:
         source:
           system: internal
           trigger: webhook
         if_match:
           url: /foo/bar
       do:
         call_workflow: do_something
   

Systems
=======

circleci
--------

This system enables Honeydipper to integrate with `circleci`, so Honeydipper can
trigger pipelines in `circleci`.


**Configurations**

:circle_token: The token for making API calls to `circleci`.

:url: The base url of the API calls, defaults to :code:`https://circleci.com/api/v2`

:org: The default org name

Function: add_env_var
^^^^^^^^^^^^^^^^^^^^^

Add env var to a project.


**Input Contexts**

:vcs: The VCS system integrated with this circle project, :code:`github` (default) or :code:`bitbucket`.

:git_repo: The repo that the env var is for, e.g. :code:`myorg/myrepo`, takes precedent over :code:`repo`.

:repo: The repo name that the env var is for, without the org, e.g. :code:`myrepo`

:name: Env var name

:value: Env var value

Function: api
^^^^^^^^^^^^^

This is a generic function to make a circleci API call with the configured token. This function is meant to be used for defining other functions.


Function: start_pipeline
^^^^^^^^^^^^^^^^^^^^^^^^

This function will trigger a pipeline in the given circleci project and branch.


**Input Contexts**

:vcs: The VCS system integrated with this circle project, :code:`github` (default) or :code:`bitbucket`.

:git_repo: The repo that the pipeline execution is for, e.g. :code:`myorg/myrepo`, takes precedent over :code:`repo`.

:repo: The repo name that the pipeline execution is for, without the org, e.g. :code:`myrepo`

:git_branch: The branch that the pipeline execution is on.

:pipeline_parameters: The parameters passed to the pipeline.

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         driver: webhook
         if_match:
           url: /from_circle
         export:
           git_repo: $event.form.git_repo.0
           git_branch: $event.form.git_branch.0
           ci_workflow: $event.form.ci_workflow.0
       do:
         call_workflow: process_and_return_to_circle
   
   workflows:
     process_and_return_to_circle:
       on_error: continue
       steps:
         - call_workflow: $ctx.ci_workflow
           export_on_success:
             pipeline_parameters:
               deploy_success: "true"
         - call_function: circleci.start_pipeline
   

Your :code:`circleci.yaml` might look like below

.. code-block:: yaml

   ---
   jobs:
     version: 2
     deploy:
       unless: << pipeline.parameters.via.honeydipper >>
       steps:
         - ...
         - run: curl <honeydipper webhook> # trigger workflow on honeydipper
     continue_on_success:
       when: << pipeline.parameters.deploy_success >>
       steps:
         - ...
         - run: celebration
     continue_on_failure:
       when:
         and:
           - << pipeline.parameters.via.honeydipper >>
           - not: << pipeline.parameters.deploy_success >>
       steps:
         - ...
         - run: recovering
         - run: # return error here
   
   workflows:
     version: 2
     deploy:
       jobs:
         - deploy
         - continue_on_success
         - continue_on_failure
     filters:
       branches:
         only: /^main$/
   

For detailed information on conditional jobs and workflows please see the
`circleci support document <https://support.circleci.com/hc/en-us/articles/360043638052-Conditional-steps-in-jobs-and-conditional-workflows>`_.


codeclimate
-----------

This system enables Honeydipper to integrate with `CodeClimate`.


**Configurations**

:api_key: The token for authenticating with CodeClimate

:url: The CodeClimate API URL

:org: For private repos, this is the default org name

:org_id: For private repos, this is the default org ID

For example

.. code-block:: yaml

   ---
   systems:
     codeclimate:
       data:
         api_key: ENC[gcloud-kms,...masked...]
         url: "https://api.codeclimate.com/v1"
   

To configure the integration in CodeClimate,

1. navigate to :code:`User Settings` => :code:`API Access`
2. generate a new token, and record it as :code:`api_key` in system data


Function: add_private_repo
^^^^^^^^^^^^^^^^^^^^^^^^^^

Add a private GitHub repository to Code Climate.


**Input Contexts**

:org_id: Code Climate organization ID, if missing use pre-configured :code:`sysData.org_id`

:org: Github organization name, if missing use pre-configured :code:`sysData.org`

:repo: Github repository name

Function: add_public_repo
^^^^^^^^^^^^^^^^^^^^^^^^^

Add a GitHub open source repository to Code Climate.


**Input Contexts**

:repo: The repo to add, e.g. :code:`myuser/myrepo`

Function: api
^^^^^^^^^^^^^

This is a generic function to make a circleci API call with the configured token. This function is meant to be used for defining other functions.


Function: get_repo_info
^^^^^^^^^^^^^^^^^^^^^^^

Get repository information


**Input Contexts**

:org: Github organization name, if missing use pre-configured :code:`sysData.org`

:repo: Github repository name

github
------

This system enables Honeydipper to integrate with `github`, so Honeydipper can
react to github events and take actions on `github`.


**Configurations**

:oauth_token: The token or API ID used for making API calls to `github`

:token: A token used for authenticate incoming webhook requests, every webhook request must carry a form field **Token** in the post body or url query that matches the value


:path: The path portion of the webhook url, by default :code:`/github/push`

For example

.. code-block:: yaml

   ---
   systems:
     github:
       data:
         oauth_token: ENC[gcloud-kms,...masked...]
         token: ENC[gcloud-kms,...masked...]
         path: "/webhook/github"
   

Assuming the domain name for the webhook server is :code:`myhoneydipper.com', you should configure the webhook in your repo with url like below

.. code-block::

   https://myhoneydipper.com/webhook/github?token=...masked...


Trigger: commit_status
^^^^^^^^^^^^^^^^^^^^^^

This is triggered when a **github** commit status is updated.

**Matching Parameters**

:.json.repository.full_name: Specify this in the :code:`when` section of the rule using :code:`if_match`, to filter the events for the repo

:.json.branches.name: This field is to match only the status events happened on certain branches

:.json.context: This field is to match only the status events with certain check name, e.g. :code:`ci/circleci: yamllint`

:.json.state: This field is to match only the status events with certain state, :code:`pending`, :code:`success`(default), :code:`failure` or :code:`error`

**Export Contexts**

:git_repo: This context variable will be set to the name of the repo, e.g. :code:`myorg/myrepo`

:branches: A list of branches that contain the commit

:git_commit: This context variable will be set to the short (7 characters) commit hash of the head commit of the push

:git_status_state: This context variable will be set to the state of the status, e.g. :code:`pending`, :code:`success`, :code:`failure` or :code:`error`

:git_status_context: This context variable will be set to the name of the status, e.g. :code:`ci/circleci: yamllint`

:git_status_description: This context variable will be set to the description of the status, e.g. :code:`Your tests passed on CircleCI!`

See below snippet for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: github
           trigger: commit_status
         if_match:
           json:
             repository:
               full_name: myorg/myrepo # .json.repository.full_name
             branches:
               name: main              # .json.branches.name
             context: mycheck          # .json.context
             state: success            # .json.state
       do:
         call_workflow: do_something
         # following context variables are available
         #   git_repo
         #   branches
         #   git_commit
         #   git_status_state
         #   git_status_context
         #   git_status_description
         #
   

Trigger: hit
^^^^^^^^^^^^

This is a catch all event for github webhook requests. It is not to be used directly, instead should be used as source for defining other triggers.


Trigger: pr_comment
^^^^^^^^^^^^^^^^^^^

This is triggered when a comment is added to a  pull request.

**Matching Parameters**

:.json.repository.full_name: This field is to match only the pull requests from certain repo

:.json.comment.user.login: This is to match only the comments from certain username

:.json.comment.author_association: This is to match only the comments from certain type of user. See github API reference `here <https://developer.github.com/v4/enum/commentauthorassociation/>`_ for detail.


:.json.comment.body: This field contains the comment message, you can use regular express pattern to match the content of the message.


**Export Contexts**

:git_repo: This context variable will be set to the name of the repo, e.g. :code:`myorg/myrepo`

:git_user: This context variable will be set to the user object who made the comment

:git_issue: This context variable will be set to the issue number of the PR

:git_message: This context variable will be set to the comment message

See below snippet for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: github
           trigger: pr_commented
         if_match:
           json:
             repository:
               full_name: myorg/myrepo # .json.repository.full_name
             comment:
               autho_association: CONTRIBUTOR
               body: ':regex:^\s*terraform\s+plan\s*$'
       do:
         call_workflow: do_terraform_plan
         # following context variables are available
         #   git_repo
         #   git_issue
         #   git_message
         #   git_user
         #
   

Trigger: pull_request
^^^^^^^^^^^^^^^^^^^^^

This is triggered when a new pull request is created

**Matching Parameters**

:.json.repository.full_name: This field is to match only the pull requests from certain repo

:.json.pull_request.base.ref: This field is to match only the pull requests made to certain base branch, note that the ref value here does not have the :code:`ref/heads/` prefix (different from push event). So to match master branch, just use :code:`master` instead of :code:`ref/heads/master`.


:.json.pull_request.user.login: This field is to match only the pull requests made by certain user

**Export Contexts**

:git_repo: This context variable will be set to the name of the repo, e.g. :code:`myorg/myrepo`

:git_ref: This context variable will be set to the name of the branch, e.g. :code:`mybrach`, no :code:`ref/heads/` prefix

:git_commit: This context variable will be set to the short (7 characters) commit hash of the head commit of the PR

:git_user: This context variable will be set to the user object who created the PR

:git_issue: This context variable will be set to the issue number of the PR

:git_title: This context variable will be set to the title of the PR

See below snippet for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: github
           trigger: pull_request
         if_match:
           json:
             repository:
               full_name: myorg/myrepo # .json.repository.full_name
             pull_request:
               base:
                 ref: master           # .json.pull_request.base.ref
       do:
         call_workflow: do_something
         # following context variables are available
         #   git_repo
         #   git_ref
         #   git_commit
         #   git_issue
         #   git_title
         #   git_user
         #
   

Trigger: push
^^^^^^^^^^^^^

This is triggered when **github** receives a push.

**Matching Parameters**

:.json.repository.full_name: Specify this in the :code:`when` section of the rule using :code:`if_match`, to filter the push events for the repo

:.json.ref: This field is to match only the push events happened on certain branch

**Export Contexts**

:git_repo: This context variable will be set to the name of the repo, e.g. :code:`myorg/myrepo`

:git_ref: This context variable will be set to the name of the branch, e.g. :code:`ref/heads/mybrach`

:git_commit: This context variable will be set to the short (7 characters) commit hash of the head commit of the push

See below snippet for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: github
           trigger: push
         if_match:
           json:
             repository:
               full_name: myorg/myrepo # .json.repository.full_name
             ref: ref/heads/mybranch   # .json.ref
       do:
         call_workflow: do_something
         # following context variables are available
         #   git_repo
         #   git_ref
         #   git_commit
         #
   

Or, you can match the conditions in workflow using exported context variables instead of in the rules

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: github
           trigger: push
       do:
         if_match:
           - git_repo: mycompany/myrepo
             git_ref: ref/heads/master
           - git_repo: myorg/myfork
             git_ref: ref/heads/mybranch
         call_workflow: do_something
   

Function: addRepoToInstallation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This function will add a repo into an installed github app


**Input Contexts**

:installation_id: The installation_id of your github app

:repoid: The Id of your github repository

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         driver: webhook
         if_match:
           url: /addrepoinstallation
       do:
         call_workflow: github_add_repo_installation
   
   workflows:
     github_add_repo_installation:
       call_function: github.addRepoToInstallation
       with:
         repoid: 12345678
         intallationid: 12345678
   

Function: api
^^^^^^^^^^^^^

This is a generic function to make a github API call with the configured oauth_token. This function is meant to be used for defining other functions.


**Input Contexts**

:resource_path: This field is used as the path portion of the API call url

Function: createComment
^^^^^^^^^^^^^^^^^^^^^^^

This function will create a comment on the given PR


**Input Contexts**

:git_repo: The repo that commit is for, e.g. :code:`myorg/myrepo`

:git_issue: The issue number of the PR

:message: The content of the comment to be posted to the PR

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: github
           trigger: pull_request
       do:
         if_match:
           git_repo: myorg/myrepo
           git_ref: master
         call_function: github.createComment
         with:
           # the git_repo is available from event export
           # the git_issue is available from event export
           message: type `honeydipper help` to see a list of available commands
   

Function: createPR
^^^^^^^^^^^^^^^^^^

This function will create a pull request with given infomation


**Input Contexts**

:git_repo: The repo that the new PR is for, e.g. :code:`myorg/myrepo`

:PR_content: The data structure to be passed to github for creating the PR, see `here <https://developer.github.com/v3/pulls/#input>`_ for detail

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         driver: webhook
         if_match:
           url: /createPR
       do:
         call_workflow: github_create_PR
   
   workflows:
     github_create_PR:
       call_function: github.createPR
       with:
         git_repo: myorg/myreop
         PR_content:
           title: update the data
           head: mybranch
           body: |
             The data needs to be updated
   
             This PR is created using honeydipper
   

Function: createRepo
^^^^^^^^^^^^^^^^^^^^

This function will create a github repository for your org


**Input Contexts**

:org: the name of your org

:name: The name of your repository

:private: privacy of your repo, either true or false(it's default to false if not declared)

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         driver: webhook
         if_match:
           url: /createrepo
       do:
         call_workflow: github_create_repo
   
   workflows:
     github_create_repo:
       call_function: github.createRepo
       with:
         org: testing
         name: testing-repo
   

Function: createStatus
^^^^^^^^^^^^^^^^^^^^^^

This function will create a commit status on the given commit.


**Input Contexts**

:git_repo: The repo that commit is for, e.g. :code:`myorg/myrepo`

:git_commit: The short commit hash for the commit the status is for

:context: the status context, a name for the status message, by default :code:`Honeydipper`

:status: the status data structure according github API `here <https://developer.github.com/v3/repos/statuses/#parameters>`_

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: github
           trigger: push
       do:
         if_match:
           git_repo: myorg/myrepo
           git_ref: ref/heads/testbranch
         call_workflow: post_status
   
   workflows:
     post_status:
       call_function: github.createStatus
       with:
         # the git_repo is available from event export
         # the git_commit is available from event export
         status:
           state: pending
           description: Honeydipper is scanning your commit ...
   

Function: getContent
^^^^^^^^^^^^^^^^^^^^

This function will fetch a file from the specified repo and branch.


**Input Contexts**

:git_repo: The repo from where to download the file, e.g. :code:`myorg/myrepo`

:git_ref: The branch from where to download the file, no :code:`ref/heads/` prefix, e.g. :code:`master`

:path: The path for fetching the file, no slash in the front, e.g. :code:`conf/nginx.conf`

**Export Contexts**

:file_content: The file content as a string

See below for example

.. code-block:: yaml

   ---
   workflows:
     fetch_circle:
       call_function: github.getContent
       with:
         git_repo: myorg/mybranch
         git_ref: master
         path: .circleci/config.yml
       export:
         circleci_conf: :yaml:{{ .ctx.file_content }}
   

Function: getRepo
^^^^^^^^^^^^^^^^^

This function will query the detailed information about the repo.


**Input Contexts**

:git_repo: The repo that the query is for, e.g. :code:`myorg/myrepo`

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         driver: webhook
         if_match:
           url: /displayRepo
       do:
         call_workflow: query_repo
   
   workflows:
     query_repo:
       steps:
         - call_function: github.getRepo
           with:
             git_repo: myorg/myreop
         - call_workflow: notify
           with:
             message: The repo is created at {{ .ctx.repo.created_at }}
   

Function: removeRepoFromInstallation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This function will remove a repo from an installed github app


**Input Contexts**

:installation_id: The installation_id of your github app

:repoid: The Id of your github repository

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         driver: webhook
         if_match:
           url: /removerepoinstallation
       do:
         call_workflow: github_remove_repo_installation
   
   workflows:
     github_remove_repo_installation:
       call_function: github.removeRepoFromInstallation
       with:
         repoid: 12345678
         intallationid: 12345678
   

jira
----

This system enables Honeydipper to integrate with `jira`, so Honeydipper can
react to jira events and take actions on jira.


**Configurations**

:jira_credential: The credential used for making API calls to `jira`

:token: A token used for authenticate incoming webhook requests, every webhook request must carry a form field **Token** in the post body or url query that matches the value


:path: The path portion of the webhook url, by default :code:`/jira`

:jira_domain: Specify the jira domain, e.g. :code:`mycompany` for :code:`mycompany.atlassian.net`

:jira_domain_base: The DNS zone of the jira API urls, in case of accessing self hosted jira, defaults to :code:`atlassian.net`

For example

.. code-block:: yaml

   ---
   systems:
     github:
       data:
         jira_credential: ENC[gcloud-kms,...masked...]
         jira_domain: mycompany
         token: ENC[gcloud-kms,...masked...]
         path: "/webhook/jira"
   

Assuming the domain name for the webhook server is :code:`myhoneydipper.com', you should configure the webhook in your repo with url like below

.. code-block::

   https://myhoneydipper.com/webhook/jira?token=...masked...


Trigger: hit
^^^^^^^^^^^^

This is a generic trigger for jira webhook events.

Function: addComment
^^^^^^^^^^^^^^^^^^^^

This function will add a comment to the jira ticket


**Input Contexts**

:jira_ticket: The ticket number that the comment is for

:comment_body: Detailed description of the comment

See below for example

.. code-block:: yaml

   ---
   workflows:
     post_comments:
       call_function: jira.addComment
       with:
         jira_ticket: $ctx.jira_ticket
         comment_body: |
           Ticket has been created by Honeydipper.
   

Function: createTicket
^^^^^^^^^^^^^^^^^^^^^^

This function will create a jira ticket with given information, refer to `jira rest API document<https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-post>`_ for description of the fields and custom fields.


**Input Contexts**

:ticket.project.key: The name of the jira project the ticket is created in

:ticket.summary: A summary of the ticket

:ticket.description: Detailed description of the work for this ticket

:ticket.issuetype.name: The ticket type

:ticket.components: Optional, a list of components associated with the ticket

:ticket.labels: Optional, a list of strings used as labels

**Export Contexts**

:jira_ticket: The ticket number of the newly created ticket

See below for example

.. code-block:: yaml

   ---
   workflows:
     create_jira_ticket:
       call_function: jira.createTicket
       with:
         ticket:
           project:
             key: devops
           issuetype:
             name: Task
           summary: upgrading kubernetes
           description: |
             Upgrade the test cluster to kubernetes 1.16
           components:
             - name: GKE
             - name: security
           labels:
             - toil
             - small
   

kubernetes
----------

This system enables Honeydipper to interact with kubernetes clusters. This system
is intended to be extended to create systems represent actual kubernetes clusters,
instead of being used directly.


**Configurations**

:source: The parameters used for fetching kubeconfig for accessing the cluster, should at least contain a :code:`type` field. Currently, only :code:`local` or :code:`gcloud-gke` are supported. For :code:`gcloud-gke` type, this should also include :code:`service_account`, :code:`project`, :code:`zone`, and :code:`cluster`.


:namespace: The namespace of the resources when operating on the resources within the cluster, e.g. deployments. By default, :code:`default` namespace is used.


For example

.. code-block:: yaml

   ---
   systems:
     my_gke_cluster:
       extends:
         - kubernetes
       data:
         source:
           type: gcloud-gke
           service_account: ENC[gcloud-kms,...masked...]
           zone: us-central1-a
           project: foo
           cluster: bar
         namespace: mynamespace
   

Function: createJob
^^^^^^^^^^^^^^^^^^^

This function creates a k8s run-to-completion job with given job spec data structure. It is a wrapper for the kubernetes driver createJob rawAction.  It leverages the pre-configured system data to access the kubernetes cluster. It is recommmended to use the helper workflows instead of using the job handling functions directly.


**Input Contexts**

:job: The job data structure following the specification for a run-to-completion job manifest yaml file.

:fromCronJob: Creating the job based on the definition of a cronjob, in the form of :code:`namespace/cronjob`. If the namespace is omitted, the current namespace where the job is being created will be used for looking up the cronjob.


**Export Contexts**

:jobid: The job ID of the created job

See below for example

.. code-block:: yaml

   ---
   workflow:
     create_job:
       call_function: my-k8s-cluster.createJob
       with:
         job:
           apiVersion: batch/v1
           kind: Job
           metadata:
             name: pi
           spec:
             template:
               spec:
                 containers:
                 - name: pi
                   image: perl
                   command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
                 restartPolicy: Never
             backoffLimit: 4
   

Function: deleteJob
^^^^^^^^^^^^^^^^^^^

This function deletes a kubernetes job specified by the job name in :code:`.ctx.jobid`. It leverages the pre-configured system data to access the kubernetes cluster.


**Input Contexts**

:jobid: The name of the kubernetes job

See below for example

.. code-block:: yaml

   ---
   workflows:
     run_myjob:
       - call_function: myk8scluster.createJob
         ...
         # this function exports .ctx.jobid
       - call_function: myk8scluster.waitForJob
         ...
       - call_function: myk8scluster.deleteJob
   

This function is not usually used directly by users. It is added to the :ref:`run_kubernetes` workflow so that, upon successful completion, the job will be deleted. In rare cases, you can use the wrapper workflow :ref:`cleanup_k8s_job` to delete a job.


Function: getJobLog
^^^^^^^^^^^^^^^^^^^

This function fetch all the logs for a k8s job with the given jobid. It is a wrapper for the kubernetes driver getJobLog rawAction.  It leverages the pre-configured system data to access the kubernetes cluster. It is recommmended to use the helper workflows instead of using the job handling functions directly.


**Input Contexts**

:job: The ID of the job to fetch logs for

**Export Contexts**

:log: The logs organized in a map of pod name to a map of container name to logs.

:output: The logs all concatinated into a single string

See below for example

.. code-block:: yaml

   ---
   workflow:
     run_simple_job:
       steps:
         - call_function: my-k8s-cluster.createJob
           with:
             job: $ctx.job
         - call_function: my-k8s-cluster.waitForJob
           with:
             job: $ctx.jobid
         - call_workflow: my-k8s-cluster.getJobLog
           with:
             job: $ctx.jobid
   

Function: recycleDeployment
^^^^^^^^^^^^^^^^^^^^^^^^^^^

This function is a wrapper to the kubernetes driver recycleDeployment rawAction. It leverages the pre-configured system data to access the kubernetes cluster.


**Input Contexts**

:deployment: The selector for identify the deployment to restart, e.g. :code:`app=nginx`

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: opsgenie
           trigger: alert
       do:
         steps:
           - if_match:
               alert_message: :regex:foo-deployment
             call_function: my-k8s-cluster.recycleDeployment
             with:
               deployment: app=foo
           - if_match:
               alert_message: :regex:bar-deployment
             call_function: my-k8s-cluster.recycleDeployment
             with:
               deployment: app=bar
   

Function: waitForJob
^^^^^^^^^^^^^^^^^^^^

This function blocks and waiting for a k8s run-to-completion job to finish. It is a wrapper for the kubernetes driver waitForJob rawAction.  It leverages the pre-configured system data to access the kubernetes cluster. It is recommmended to use the helper workflows instead of using the job handling functions directly.


**Input Contexts**

:job: The job id that the function will wait for to reach terminated states

**Export Contexts**

:job_status: The status of the job, either :code:`success` or :code:`failure`

See below for example

.. code-block:: yaml

   ---
   workflow:
     run_simple_job:
       steps:
         - call_function: my-k8s-cluster.createJob
           with:
             job: $ctx.job
         - call_function: my-k8s-cluster.waitForJob
           with:
             job: $ctx.jobid
         - call_workflow: notify
           with:
             message: the job status is {{ .job_status }}
   

opsgenie
--------

This system enables Honeydipper to integrate with `opsgenie`, so Honeydipper can
react to opsgenie alerts and take actions through opsgenie API.


**Configurations**

:API_KEY: The API key used for making API calls to `opsgenie`

:token: A token used for authenticate incoming webhook requests, every webhook request must carry a form field **Token** in the post body or url query that matches the value


:path: The path portion of the webhook url, by default :code:`/opsgenie`

For example

.. code-block:: yaml

   ---
   systems:
     opsgenie:
       data:
         API_KEY: ENC[gcloud-kms,...masked...]
         token: ENC[gcloud-kms,...masked...]
         path: "/webhook/opsgenie"
   

Assuming the domain name for the webhook server is :code:`myhoneydipper.com', you should configure the webhook in your opsgenie integration with url like below

.. code-block::

   https://myhoneydipper.com/webhook/opsgenie?token=...masked...


Trigger: alert
^^^^^^^^^^^^^^

This event is triggered when an opsgenie alert is raised.

**Matching Parameters**

:.json.alert.message: This field can used to match alert with only certain messages

:.json.alert.alias: This field is to match only the alerts with certain alias

**Export Contexts**

:alert_message: This context variable will be set to the detailed message of the alert.

:alert_alias: This context variable will be set to the alias of the alert.

:alert_Id: This context variable will be set to the short alert ID.

:alert_system: This context variable will be set to the constant string, :code:`opsgenie`

:alert_url: This context variable will be set to the url of the alert, used for creating links

See below snippet for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: opsgenie
           trigger: alert
         if_match:
           json:
             alert:
               message: :regex:^test-alert.*$
       do:
         call_workflow: notify
         with:
           message: 'The alert url is {{ .ctx.alert_url }}'
   

Function: contact
^^^^^^^^^^^^^^^^^

This function gets the user's contact methods


**Input Contexts**

:userId: The ID of the user for which to get contact methods

**Export Contexts**

:contacts: The detail of user's contact method in a map, or a list of user's contact methods

See below for example

.. code-block:: yaml

   ---
   workflows:
     steps:
       - call_workflow: do_something
       - call_function: opsgenie.contact
         with:
           userId: username@example.com
   

Function: heartbeat
^^^^^^^^^^^^^^^^^^^

This function will send a heartbeat request to opsgenie.


**Input Contexts**

:heartbeat: The name of the heartbeat as configured in your opsgenie settings

**Export Contexts**

:result: The return result of the API call

See below for example

.. code-block:: yaml

   ---
   workflows:
     steps:
       - call_workflow: do_something
       - call_function: opsgenie.heartbeat
         with:
           heartbeat: test-heart-beat
   

Function: schedules
^^^^^^^^^^^^^^^^^^^

This function list all on-call schedules or fetch a schedule detail if given a schedule identifier.

.. important::
   This function only fetches first 100 schedules when listing.

**Input Contexts**

:scheduleId: The name or ID or the schedule of interest; if missing, list all schedules.

:scheduleIdType: The type of the identifier, :code:`name` or :code:`id`.

**Export Contexts**

:schedule: For fetching detail, the data structure that contains the schedule detail

:schedules: For listing, a list of data structure contains the schedule details

See below for example

.. code-block:: yaml

   ---
   workflows:
     steps:
       - call_function: opsgenie.schedules
   

Function: snooze
^^^^^^^^^^^^^^^^

This function will snooze the alert with given alert ID.


**Input Contexts**

:alert_Id: The ID of the alert to be snoozed

:duration: For how long the alert should be snoozed, use golang time format

**Export Contexts**

:result: The return result of the API call

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: opsgenie
           trigger: alert
       do:
         if_match:
           alert_message: :regex:test-alert
         call_function: opsgenie.snooze
         #  alert_Id is exported from the event
   

Function: users
^^^^^^^^^^^^^^^

This function gets the user detail with a given ID or list all users

**Input Contexts**

:userId: The ID of the user for which to get details; if missing, list users

:offset: Number of users to skip from start, used for paging

:query: :code:`Field:value` combinations with most of user fields to make more advanced searches. Possible fields are :code:`username`, :code:`fullName blocked`, :code:`verified`, :code:`role`, :code:`locale`, :code:`timeZone`, :code:`userAddress` and :code:`createdAt`

:order: The direction of the sorting, :code:`asc` or :code:`desc`, default is :code:`asc`

:sort: The field used for sorting the result, could be :code:`username`, :code:`fullname` or :code:`insertedAt`.

**Export Contexts**

:user: The detail of user in a map, or a list of users

:users: The detail of user in a map, or a list of users

:opsgenie_offset: The offset that can be used for continue fetching the rest of the users, for paging

See below for example

.. code-block:: yaml

   ---
   workflows:
     steps:
       - call_function: opsgenie.users
         with:
           query: username:foobar
   

Function: whoisoncall
^^^^^^^^^^^^^^^^^^^^^

This function gets the current on-call persons for the given schedule.

.. important::
   Use the `opsgenie_whoisoncall`_ workflow instead.

**Input Contexts**

:scheduleId: The name or ID or the schedule of interest, required

:scheduleIdType: The type of the identifier, :code:`name` or :code:`id`.

:flat: If true, will only return the usernames, otherwise, will return all including notification, team etc.

**Export Contexts**

:result: the data portion of the json payload.

See below for example

.. code-block:: yaml

   ---
   workflows:
     steps:
       - call_function: opsgenie.whoisoncall
         with:
           scheduleId: sre_schedule
   

pagerduty
---------

This system enables Honeydipper to integrate with :code:`pagerduty`, so Honeydipper can
react to pagerduty alerts and take actions through pagerduty API.


**Configurations**

:API_KEY: The API key used for making API calls to :code:`pagerduty`

:signatureSecret: The secret used for validating webhook requests from :code:`pagerduty`

:path: The path portion of the webhook url, by default :code:`/pagerduty`

For example

.. code-block:: yaml

   ---
   systems:
     pagerduty:
       data:
         API_KEY: ENC[gcloud-kms,...masked...]
         signatureSecret: ENC[gcloud-kms,...masked...]
         path: "/webhook/pagerduty"
   

Assuming the domain name for the webhook server is :code:`myhoneydipper.com', you should configure the webhook in your pagerduty integration with url like below

.. code-block::

   https://myhoneydipper.com/webhook/pagerduty


Trigger: alert
^^^^^^^^^^^^^^

This event is triggered when an pagerduty incident is raised.

**Matching Parameters**

:.json.event.data.title: This field can used to match alert with only certain messages

:.json.event.data.service.summary: This field is to match only the alerts with certain service

**Export Contexts**

:alert_message: This context variable will be set to the detailed message of the alert.

:alert_service: This context variable will be set to the service of the alert.

:alert_Id: This context variable will be set to the short alert ID.

:alert_system: This context variable will be set to the constant string, :code:`pagerduty`

:alert_url: This context variable will be set to the url of the alert, used for creating links

Pagerduty manages all the alerts through incidents. Although the trigger is named :code:`alert` for compatibility reason, it actually matches an incident.

See below snippet for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: pagerduty
           trigger: alert
         if_match:
           json:
             data:
               title: :regex:^test-alert.*$
       do:
         call_workflow: notify
         with:
           message: 'The alert url is {{ .ctx.alert_url }}'
   

Function: api
^^^^^^^^^^^^^

No description is available for this entry!

Function: getEscalationPolicies
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

No description is available for this entry!

Function: snooze
^^^^^^^^^^^^^^^^

snooze pagerduty incident


**Input Contexts**

:alert_Id: The ID of the incident to be snoozed

:duration: For how long the incident should be snoozed, a number of seconds

**Export Contexts**

:incident: On success, returns the updated incident object

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: pagerduty
           trigger: alert
         if_match:
           json:
             title: :regex:test-alert
       do:
         call_function: pagerduty.snooze
         with:
           # alert_Id is exported from the event
           duration: 1200
   

Function: whoisoncall
^^^^^^^^^^^^^^^^^^^^^

This function gets the current on-call persons for the given schedule.

.. important::
   This function only fetches first 100 schedules when listing. Use `pagerduty_whoisoncall`_ workflow instead.

**Input Contexts**

:escalation_policy_ids: An array of IDs of the escalation policies; if missing, list all.

**Export Contexts**

:result: a list of data structure contains the schedule details. See `API <https://developer.pagerduty.com/api-reference/reference/REST/openapiv3.json/paths/~1oncalls/get>`_ for detail.

See below for example

.. code-block:: yaml

   ---
   workflows:
     until:
       - $?ctx.EOL
     steps:
       - call_function: pagerduty.whoisoncall
     no_export:
       - offset
       - EOL
   

slack
-----

This system enables Honeydipper to integrate with `slack`, so Honeydipper can
send messages to and react to commands from slack channels. This system uses :code:`Custom
Integrations` to integrate with slack. It is recommended to use :code:`slack_bot` system, which uses
a slack app to integrate with slack.


**Configurations**

:url: The slack incoming webhook integration url

:slash_token: The token for authenticating slash command requests

:slash_path: The path portion of the webhook url for receiving slash command requests, by default :code:`/slack/slashcommand`

For example

.. code-block:: yaml

   ---
   systems:
     slack:
       data:
         url: ENC[gcloud-kms,...masked...]
         slash_token: ENC[gcloud-kms,...masked...]
         slash_path: "/webhook/slash"
   

To configure the integration in slack,

1. select from menu :code:`Administration` => :code:`Manage Apps`
2. select :code:`Custom Integrations`
3. add a :code:`Incoming Webhooks`, and copy the webhook url and use it as :code:`url` in system data
4. create a random token to be used in slash command integration, and record it as :code:`slash_token` in system data
5. add a :code:`Slash Commands`, and use the url like below to send commands


.. code-block::

   https://myhoneydipper.com/webhook/slash?token=...masked...


Trigger: slashcommand
^^^^^^^^^^^^^^^^^^^^^

This is triggered when an user issue a slash command in a slack channel. It is recommended to use the helper workflows
and the predefined rules instead of using this trigger directly.


**Matching Parameters**

:.form.text: The text of the command without the prefix

:.form.channel_name: This field is to match only the command issued in a certain channel, this is only available for public channels

:.form.channel_id: This field is to match only the command issued in a certain channel

:.form.user_name: This field is to match only the command issued by a certain user

**Export Contexts**

:response_url: Used by the :code:`reply` function to send reply messages

:text: The text of the command without the slash word prefix

:channel_name: The name of the channel without `#` prefix, this is only available for public channels

:channel_fullname: The name of the channel with `#` prefix, this is only available for public channels

:channel_id: The IDof the channel

:user_name: The name of the user who issued the command

:command: The first word in the text, used as command keyword

:parameters: The remaining string with the first word removed

See below snippet for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: slack
           trigger: slashcommand
         if_match:
           form:
             channel_name:
               - public_channel1
               - channel2
         steps:
           - call_function: slack.reply
             with:
               chat_colors:
                 this: good
               message_type: this
               message: command received `{{ .ctx.command }}`
           - call_workflow: do_something
   

Function: add_response
^^^^^^^^^^^^^^^^^^^^^^

No description is available for this entry!

Function: reply
^^^^^^^^^^^^^^^

This function send a reply message to a slash command request. It is recommended to use :code:`notify` workflow instead so we can manage the colors, message types and receipient lists through contexts easily.


**Input Contexts**

:chat_colors: a map from message_types to color codes

:message_type: a string that represents the type of the message, used for selecting colors

:message: the message to be sent

:blocks: construct the message using the slack :code:`layout blocks`, see slack document for detail

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: slack
           trigger: slashcommand
       do:
         call_function: slack.reply
         with:
           chat_colors:
             critical: danger
             normal: ""
             error: warning
             good: good
             special: "#e432ad2e"
           message_type: normal
           message: I received your request.
   

Function: say
^^^^^^^^^^^^^

This function send a message to a slack channel slack incoming webhook. It is recommended to use :code:`notify` workflow instead so we can manage the colors, message types and receipient lists through contexts easily.


**Input Contexts**

:chat_colors: A map from message_types to color codes

:message_type: A string that represents the type of the message, used for selecting colors

:message: The message to be sent

:channel_id: The id of the channel the message is sent to. Use channel name here only when sending to a public channel or to the home channel of the webhook.


:blocks: construct the message using the slack :code:`layout blocks`, see slack document for detail

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: something
           trigger: happened
       do:
         call_function: slack.say
         with:
           chat_colors:
             critical: danger
             normal: ""
             error: warning
             good: good
             special: "#e432ad2e"
           message_type: error
           message: Something happened
           channel_id: '#public_announce'
   

Function: send_message
^^^^^^^^^^^^^^^^^^^^^^

No description is available for this entry!

Function: update_message
^^^^^^^^^^^^^^^^^^^^^^^^

No description is available for this entry!

slack_bot
---------

This system enables Honeydipper to integrate with `slack`, so Honeydipper can
send messages to and react to commands from slack channels. This system uses slack app
to integrate with slack. It is recommended to use this instead of :code:`slack` system, which uses
a :code:`Custom Integrations` to integrate with slack.


**Configurations**

:token: The bot user token used for making API calls

:slash_token: The token for authenticating slash command requests

:interact_token: The token for authenticating slack interactive messages

:slash_path: The path portion of the webhook url for receiving slash command requests, by default :code:`/slack/slashcommand`

:interact_path: The path portion of the webhook url for receiving interactive component requests, by default :code:`/slack/interact`

For example

.. code-block:: yaml

   ---
   systems:
     slack_bot:
       data:
         token: ENC[gcloud-kms,...masked...]
         slash_token: ENC[gcloud-kms,...masked...]
         interact_token: ENC[gcloud-kms,...masked...]
         slash_path: "/webhook/slash"
         interact_path: "/webhook/slash_interact"
   

To configure the integration in slack,

1. select from menu :code:`Administration` => :code:`Manage Apps`
2. select :code:`Build` from top menu, create an app or select an exist app from :code:`Your Apps`
3. add feature :code:`Bot User`, and copy the :code:`Bot User OAuth Access Token` and record it as  :code:`token` in system data
4. create a random token to be used in slash command integration, and record it as :code:`slash_token` in system data
5. add feature :code:`Slash Commands`, and use the url like below to send commands


.. code-block::

   https://myhoneydipper.com/webhook/slash?token=...masked...


6. create another random token to be used in interactive components integration, and record it as :code:`interact_token` in system data
7. add feature :code:`interactive components` and use url like below


.. code-block::

   https://myhoneydipper.com/webhook/slash_interact?token=...masked...


Trigger: interact
^^^^^^^^^^^^^^^^^

This is triggered when an user responds to an interactive component in a message. This enables honeydipper
to interactively reacts to user choices through slack messages. A builtin rule is defined to respond to this
trigger, so in normal cases, it is not necessary to use this trigger directly.


**Export Contexts**

:slack_payload: The payload of the interactive response

Trigger: slashcommand
^^^^^^^^^^^^^^^^^^^^^

This is triggered when an user issue a slash command in a slack channel. It is recommended to use the helper workflows
and the predefined rules instead of using this trigger directly.


**Matching Parameters**

:.form.text: The text of the command without the prefix

:.form.channel_name: This field is to match only the command issued in a certain channel, this is only available for public channels

:.form.channel_id: This field is to match only the command issued in a certain channel

:.form.user_name: This field is to match only the command issued by a certain user

**Export Contexts**

:response_url: Used by the :code:`reply` function to send reply messages

:text: The text of the command without the slash word prefix

:channel_name: The name of the channel without `#` prefix, this is only available for public channels

:channel_fullname: The name of the channel with `#` prefix, this is only available for public channels

:channel_id: The IDof the channel

:user_name: The name of the user who issued the command

:command: The first word in the text, used as command keyword

:parameters: The remaining string with the first word removed

See below snippet for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: slack
           trigger: slashcommand
         if_match:
           form:
             channel_name:
               - public_channel1
               - channel2
         steps:
           - call_function: slack.reply
             with:
               chat_colors:
                 this: good
               message_type: this
               message: command received `{{ .ctx.command }}`
           - call_workflow: do_something
   

Function: add_response
^^^^^^^^^^^^^^^^^^^^^^

No description is available for this entry!

Function: reply
^^^^^^^^^^^^^^^

This function send a reply message to a slash command request. It is recommended to use :code:`notify` workflow instead so we can manage the colors, message types and receipient lists through contexts easily.


**Input Contexts**

:chat_colors: a map from message_types to color codes

:message_type: a string that represents the type of the message, used for selecting colors

:message: the message to be sent

:blocks: construct the message using the slack :code:`layout blocks`, see slack document for detail

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: slack
           trigger: slashcommand
       do:
         call_function: slack.reply
         with:
           chat_colors:
             critical: danger
             normal: ""
             error: warning
             good: good
             special: "#e432ad2e"
           message_type: normal
           message: I received your request.
   

Function: say
^^^^^^^^^^^^^

This function send a message to a slack channel slack incoming webhook. It is recommended to use :code:`notify` workflow instead so we can manage the colors, message types and receipient lists through contexts easily.


**Input Contexts**

:chat_colors: A map from message_types to color codes

:message_type: A string that represents the type of the message, used for selecting colors

:message: The message to be sent

:channel_id: The id of the channel the message is sent to. Use channel name here only when sending to a public channel or to the home channel of the webhook.


:blocks: construct the message using the slack :code:`layout blocks`, see slack document for detail

See below for example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: something
           trigger: happened
       do:
         call_function: slack.say
         with:
           chat_colors:
             critical: danger
             normal: ""
             error: warning
             good: good
             special: "#e432ad2e"
           message_type: error
           message: Something happened
           channel_id: '#public_announce'
   

Function: send_message
^^^^^^^^^^^^^^^^^^^^^^

No description is available for this entry!

Function: update_message
^^^^^^^^^^^^^^^^^^^^^^^^

No description is available for this entry!

Function: users
^^^^^^^^^^^^^^^

This function queries all users for the team

**Input Contexts**

:cursor: Used for pagination, continue fetching from the cursor

**Export Contexts**

:slack_next_cursor: Used for pagination, used by next call to continue fetch

:members: A list of data structures containing member information

.. code-block:: yaml

   ---
   workflows:
     get_all_slack_users:
       call_function: slack_bot.users
   

Workflows
=========

channel_translate
-----------------

translate channel_names to channel_ids

**Input Contexts**

:channel_names: a list of channel names to be translated

:channel_maps: a map from channel names to ids

**Export Contexts**

:channel_ids: a list of channel ids corresponding to the input names

By pre-populating a map, we don't have to make API calls to slack everytime we need to convert a channel name to a ID.

This is used by :code:`slashcommand` workflow and :code:`notify` workflow to automatically translate the names.

.. code-block:: yaml

   ---
   workflows:
     attention:
       with:
         channel_map:
           '#private_channel1': UGKLASE
           '#private_channel2': UYTFYJ2
           '#private_channel3': UYUJH56
           '#private_channel4': UE344HJ
           '@private_user':     U78JS2F
       steps:
         - call_workflow: channel_translate
           with:
             channel_names:
               - '#private_channel1'
               - '#private_channel3'
               - '@private_user'
               - '#public_channel1'
         - call_workflow: loop_send_slack_message
           # with:
           #   channel_ids:
           #     - UGKLASE
           #     - UYUJH56
           #     - U78JS2F
           #     - '#public_channel1' # remain unchanged if missing from the map
   

circleci_pipeline
-----------------

This workflows wrap around the :code:`circleci.start_pipeline` function so it can be used as a hook.

For example, below workflow uses a hook to invoke the pipeline.

.. code-block:: yaml

   ---
   rules:
     - when:
         driver: webhook
         if_match:
           url: /from_circle
         export:
           git_repo: $event.form.git_repo.0
           git_branch: $event.form.git_branch.0
           ci_workflow: $event.form.ci_workflow.0
       do:
         call_workflow: process_and_return_to_circle
   
   workflows:
     process_and_return_to_circle:
       with:
         hooks:
           on_exit+:
             - circleci_pipeline
       steps:
         - call_workflow: $ctx.ci_workflow
           export_on_success:
             pipeline_parameters:
               deploy_success: "true"
   

cleanup_kube_job
----------------

delete a kubernetes job

**Input Contexts**

:system: The k8s system to use to delete the job

:no_cleanup_k8s_job: If set to truthy value, will skip deleting the job

This workflow is intended to be invoked by :ref:`run_kuberentes` workflow as a hook upon successful completion.


codeclimate/add_private_repo
----------------------------

Add a private Github repository to Code Climate

codeclimate/add_public_repo
---------------------------

Add a public Github repository to Code Climate

inject_misc_steps
-----------------

This workflow injects some helpful steps into the k8s job before making the API to create the job, based on the processed job definitions. It is not recommended to use this workflow directly. Instead, use :code:`run_kubernetes` to leverage all the predefined context variables.


notify
------

send chat message through chat system

**Input Contexts**

:chat_system: A system name that supports :code:`reply` and :code:`say` function, can be either :code:`slack` or :code:`slack_bot`, by default :code:`slack_bot`.


:notify: A list of channels to which the message is beng sent, a special name :code:`reply` means replying to the slashcommand user.


:notify_on_error: A list of additional channels to which the message is beng sent if the message_type is error or failure.


:message_type: The type of the message used for coloring, could be :code:`success`, :code:`failure`, :code:`error`, :code:`normal`, :code:`warning`, or :code:`announcement`


:chat_colors: A map from message_type to color codes. This should usually be defined in default context so it can be shared.


:update: Set to true to update a previous message identified with :code:`ts`.


This workflow wraps around :code:`say` and :code:`reply` method, and allows multiple recipients.

For example

.. code-block:: yaml

   ---
   workflows:
     attention:
       call_workflow: notify
       with:
         notify:
           - "#honeydipper-notify"
           - "#myteam"
         notify_on_error:
           - "#oncall"
         message_type: $labels.status
         message: "work status is {{ .labels.status }}"
   

opsgenie_users
--------------

This workflow wraps around the :code:`opsgenie.users` function and handles paging to get all users from Opsgenie.

opsgenie_whoisoncall
--------------------

get opsgenie on call table

This workflow wraps around multiple api calls to :code:`opsgenie` and produce a `on_call_table` datastructure.

**Input Contexts**

:schedule_pattern: Optional, the keyword used for filtering the on call schedules.

**Export Contexts**

:on_call_table: A map from on call schedule names to lists of users.

This is usually used for showing the on-call table in response to slash commands.

For example

.. code-block:: yaml

   ---
   workflows:
     show_on_calls:
       with:
         alert_system: opsgenie
       no_export:
         - '*'
       steps:
         - call: '{{ .ctx.alert_system }}_whoisoncall'
         - call: notify
           with:
             notify*:
               - reply
             response_type: in_channel
             blocks:
               - type: section
                 text:
                   type: mrkdn
                   text: |
                     *===== On call users ======*
                     {{- range $name, $users := .ctx.on_call_table }}
                     *{{ $name }}*: {{ join ", " $users }}
                     {{- end }}
   

pagerduty_whoisoncall
---------------------

get pagerduty on call table

This workflow wraps around multiple api calls to :code:`pagerduty` and produce a `on_call_table` datastructure.

**Input Contexts**

:tag_name: Optional, the keyword used for filtering the on tags

:schedule_pattern: Optional, the keyword used for filtering the on-call escalation policies.

**Export Contexts**

:on_call_table: A map from on call schedule names to lists of users.

This is usually used for showing the on-call table in response to slash commands.

For example

.. code-block:: yaml

   ---
   workflows:
     show_on_calls:
       with:
         alert_system: pagerduty
       no_export:
         - '*'
       steps:
         - call: '{{ .ctx.alert_system }}_whoisoncall'
         - call: notify
           with:
             notify*:
               - reply
             response_type: in_channel
             blocks:
               - type: section
                 text:
                   type: mrkdn
                   text: |
                     *===== On call users ======*
                     {{- range $name, $users := .ctx.on_call_table }}
                     *{{ $name }}*: {{ join ", " $users }}
                     {{- end }}
   

reload
------

reload honeydipper config

**Input Contexts**

:force: If force is truy, Honeydipper will simply quit, expecting to be re-started by deployment manager.


For example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: slack_bot
           trigger: slashcommand
       do:
         if_match:
           command: reload
         call_workflow: reload
         with:
           force: $?ctx.parameters
   

resume_workflow
---------------

resume a suspended workflow

**Input Contexts**

:resume_token: Every suspended workflow has a :code:`resume_token`, use this to match the workflow to be resumed


:labels_status: Continue the workflow with a dipper message that with the specified status


:labels_reason: Continue the workflow with a dipper message that with the specified reason


:resume_payload: Continue the workflow with a dipper message that with the given payload


For example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: slack_bot
           trigger: interact
       do:
         call_workflow: resume_workflow
         with:
           resume_token: $ctx.slack_payload.callback_id
           labels_status: success
           resume_payload: $ctx.slack_payload
   

run_kubernetes
--------------

run kubernetes job

**Input Contexts**

:system: The k8s system to use to create and run the job

:steps: The steps that the job is made up with. Each step is an :code:`initContainer` or a :code:`container`. The steps are executed one by one as ordered in the list. A failure in a step will cause the whole job to fail. Each step is defined with fields including :code:`type`, :code:`command`, or :code:`shell`. The :code:`type` tells k8s what image to use, the :code:`command` is the command to be executed with language supported by that image. If a shell script needs to be executed, use :code:`shell` instead of :code:`command`.
Also supported are :code:`env` and :code:`volumes` for defining the environment variables and volumes specific to this step.


:generateName: The prefix for all jobs created by :code:`Honeydipper`, defaults to :code:`honeydipper-job-`.

:berglas_files: Use :code:`Berglas` to fetch secret files. A list of objects, each
has a :code:`file` and a :code:`secret` field.  Optionally, you can
specify the :code:`owner`, :code:`mode` and :code:`dir_mode` for
the file. This is achieved by adding an :code:`initContainer` to
run the :code:`berglas access "$secret" > "$file"` commands.

:code:`Berglas` is a utility for handling secrets. See their
`github repo <https://github.com/GoogleCloudPlatform/berglas>`_ for
details.


:env: A list of environment variables for all the steps.


:volumes: A list of volumes to be attached for all the steps. By default, there will be a :code:`EmptyDir` volume attached at :code:`/honeydipper`. Each item should have a `name` and `volume` and optionally a `subPath`, and they will be used for creating the volume definition and volume mount definition.


:workingDir: The working directory in which the command or script to be exected. By default, :code:`/honeydipper`. Note that, the default :code:`workingDir` defined in the image is not used here.


:script_types: A map of predefined script types. The :code:`type` field in :code:`steps` will be used to select the image here. :code:`image` field is required. :code:`command_entry` is used for defining the entrypoint when using :code:`command` field in step, and :code:`command_prefix` are a list or a string that inserted at the top of container args. Correspondingly, the :code:`shell_entry` and :code:`shell_prefix` are used for defining the entrypoint and argument prefix for running a `shell` script.
Also supported is an optional :code:`securtyContext` field for defining the image security context.


:resources: Used for specifying how much of each resource a container needs. See k8s resource management for containers for detail.


:predefined_steps: A map of predefined steps. Use the name of the predefined step in :code:`steps` list to easily define a step without specifying the fields. This makes it easier to repeat or share the steps that can be used in multiple places. We can also override part of the predefined steps when defining the steps with `use` and overriding fields.


:predefined_env: A map of predefined environment variables.


:predefined_volumes: A map of predefined volumes.


:nodeSelector: See k8s pod specification for detail

:affinity: See k8s pod specification for detail

:tolerations: See k8s pod specification for detail

:timeout: Used for setting the :code:`activeDeadlineSeconds` for the k8s pod

:cleanupAfter: Used for setting the :code:`TTLSecondsAfterFinished` for the k8s job, requires 1.13+ and the alpha features to be enabled for the cluster. The feature is still in alpha as of k8s 1.18.


:no_cleanup_k8s_job: By default, the job will be deleted upon successful completion. Setting this context variable to a truthy value will ensure that the successful job is kept in the cluster.


:k8s_job_backoffLimit: By default, the job will not retry if the pod fails (:code:`backoffLimit` set to 0), you can use this to override the setting for the job.


:parallelism: Parallel job execution by setting this to a non-negative integer. If left unset, it will default to 1.


:fromCronJob: Creating the job based on the definition of a cronjob, in the form of :code:`namespace/cronjob`. If the namespace is omitted, the current namespace where the job is being created will be used for looking up the cronjob.


:job_creator: The value for the :code:`creator` label, defaults to :code:`honeydipper`. It is useful when you want to target the jobs created through this workflow using :code:`kubectl` commands with :code:`-l` option.


:on_job_start: If specified, a workflow specified by :code:`on_job_start` will be executed once the job is created. This is useful for sending notifications with job name, links to the log etc.


**Export Contexts**

:log: The logs of the job organized in map by container and by pod

:output: The concatinated log outputs as a string

:job_status: A string indicating if the job is :code:`success` or :code:`failure`

See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     ci:
       call_workflow: run_kubernetes
       with:
         system: myrepo.k8s_cluster
         steps:
           - git_clone # predefined step
           - type: node
             workingDir: /honeydipper/repo
             shell: npm install && npm build && npm test
   

Another example with overrriden predefined step

.. code-block:: yaml

   ---
   workflows:
     make_change:
       call_workflow: run_kubernetes
       with:
         system: myrepo.k8s
         steps:
           - git_clone # predefined step
           - type: bash
             shell: sed 's/foo/bar/g' repo/package.json
           - use: git_clone # use predefined step with overriding
             name: git_commit
             workingDir: /honeydipper/repo
             shell: git commit -m 'change' -a && git push
   

An example with :code:`Berglas` decryption for files. Pay attention to how the file ownership is mapped to the :code:`runAsUser`.

.. code-block:: yaml

   ---
   workflows:
     make_change:
       call_workflow: run_kubernetes
       with:
         system: myrepo.k8s
         steps:
           - use: git_clone
             env:
               - name: HOME
                 value: /honeydipper/myuser
             workingDir: /honeydipper/myuser
             securityContext:
               runAsUser: 3001
               runAsGroup: 3001
               fsGroup: 3001
           - type: node
             workingDir: /honeydipper/myuser/repo
             shell: npm ci
         berglas_files:
           - file: /honeydipper/myuser/.ssh/id_rsa
             secret: sm://my-project/my-ssh-key
             owner: "3001:3001"
             mode: "600"
             dir_mode: "600"
   

send_heartbeat
--------------

sending heartbeat to alert system

**Input Contexts**

:alert_system: The alert system used for monitoring, by default :code:`opsgenie`


:heartbeat: The name of the heartbeat


This workflow is just a wraper around the :code:`opsgenie.heartbeat` function.


slack_users
-----------

This workflow wraps around the :code:`slack_bot.users` function and make multiple calls to stitch pages together.

slashcommand
------------

This workflow is used internally to respond to slashcommand webhook events. You don't need to use this workflow directly in most cases. Instead, customize the workflow using :code:`_slashcommands` context.


**Input Contexts**

:slashcommands: A map of commands to their definitions.  Each definition should have a brief :code:`usage`, :code:`workflow` :code:`contexts`, and :code:`allowed_channels` fields. By default, two commands are already defined, :code:`help`, and :code:`reload`. You can extend the list or override the commands by defining this variable in :code:`_slashcommands` context.


:slash_notify: A recipient list that will receive notifications and status of the commands executed through slashcommand.


**Export Contexts**

:command: This variable will be passed the actual workflow invoked by the slashcommand. The command is the  first word after the prefix of the slashcommand. It is used for matching the definition in :code:`$ctx.slashcommands`.


:parameters: This variable will be passed the actual workflow invoked by the slashcommand. The parameters is a string that contains the rest of the content in the slashcommand after the first word.


You can try to convert the :code:`$ctx.parameters` to the variables the workflow required by the workflow being invoked through the :code:`_slashcommands` context.


.. code-block:: yaml

   ---
   contexts:
     _slashcommands:
   
   ######## definition of the commands ###########
       slashcommand:
         slashcommands:
           greeting:
             usage: just greet the requestor
             workflow: greet
   
   ######## setting the context variable for the invoked workflow ###########
       greet:
         recipient: $ctx.user_name # exported by slashcommand event trigger
         type: $ctx.parameters     # passed from slashcommand workflow
   

slashcommand/announcement
-------------------------

This workflow sends an announcement message to the channels listed in :code:`slash_notify`.  Used internally.


slashcommand/execute
--------------------

No description is available for this entry!

slashcommand/help
-----------------

This workflow sends a list of supported commands to the requestor.  Used internally.


slashcommand/prepare_notification_list
--------------------------------------

This workflow constructs the notification list using :code:`slash_notify`. If the command is NOT issued from one of the listed channels.


slashcommand/respond
--------------------

This workflow sends a response message to the channels listed in :code:`slash_notify`.  Used internally.


slashcommand/status
-------------------

This workflow sends a status message to the channels listed in :code:`slash_notify`.  Used internally.


snooze_alert
------------

snooze an alert

**Input Contexts**

:alert_system: The alert system used for monitoring, by default :code:`opsgenie`


:alert_Id: The Id of the alert, usually exported from the alert event


:duration: How long to snooze the alert for, using golang time format, by default :code:`20m`


This workflow is just a wraper around the :code:`opsgenie.snooze` function. It also sends a notification through chat to inform if the snoozing is success or not.


For example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: opsgenie
           trigger: alert
       do:
         steps:
           - call_workflow: snooze_alert
           - call_workflow: do_something
   

start_kube_job
--------------

This workflow creates a k8s job with given job spec. It is not recommended to use this workflow directly. Instead, use :code:`run_kubernetes` to leverage all the predefined context variables.


use_local_kubeconfig
--------------------

This workflow is a helper to add a step into :code:`steps` context variable to ensure the in-cluster kubeconfig is used. Basically, it will delete the kubeconfig files if any presents. It is useful when switching from other clusters to local cluster in the same k8s job.


.. code-block:: yaml

   ---
   workflows:
     copy_deployment_to_local:
       steps:
         - call_workflow: use_google_credentials
         - call_workflow: use_gcloud_kubeconfig
           with:
             cluster:
               project: foo
               cluster: bar
               zone: us-central1-a
         - export:
             steps+:
               - type: gcloud
                 shell: kubectl get -o yaml deployment {{ .ctx.deployment }} > kuberentes.yaml
         - call_workflow: use_local_kubeconfig # switching back to local cluster
         - call_workflow: run_kubernetes
           with:
             steps+:
               - type: gcloud
                 shell: kubectl apply -f kubernetes.yaml
   

workflow_announcement
---------------------

This workflow sends announcement messages to the slack channels. It can be used in the hooks to automatically announce the start of the workflow executions.

.. code-block:: yaml

   ---
   workflows:
     do_something:
       with:
         hooks:
           on_first_action:
             - workflow_announcement
       steps:
         - ...
         - ...
   

workflow_status
---------------

This workflow sends workflow status messages to the slack channels. It can be used in the hooks to automatically announce the exit status of the workflow executions.

.. code-block:: yaml

   ---
   workflows:
     do_something:
       with:
         hooks:
           on_exit:
             - workflow_status
       steps:
         - ...
         - ...
   

