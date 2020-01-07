Essentials
**********

The essential configurations to bootstrap Honeydipper

Installation
============

Include the following section in your **init.yaml** under **repos** section

.. code-block:: yaml

   - repo: https://github.com/honeydipper/honeydipper-config-essentials

Drivers
=======

This repo provides following drivers

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
   

redispubsub
-----------

redispubsub driver is used internally to facilitate communications between
different components of Honeydipper system.


**Configurations**

:connection: The parameters used for connecting to the redis including `Addr`, `Password` and `DB`.

See below for an example

.. code-block:: yaml

   ---
   drivers:
     redispubsub:
       connection:
         Addr: 192.168.2.10:6379
         DB: 2
         Password: ENC[gcloud-kms,...masked]
   

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

:connection: The parameters used for connecting to the redis including `Addr`, `Password` and `DB`.

See below for an example

.. code-block:: yaml

   ---
   drivers:
     redisqueue:
       connection:
         Addr: 192.168.2.10:6379
         DB: 2
         Password: ENC[gcloud-kms,...masked]
   

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
   

jira
----

This system enables Honeydipper to integrate with `jira`, so Honeydipper can
react to jira events and take actions on jira.


**Configurations**

:jira_credential: The credential used for making API calls to `jira`

:token: A token used for authenticate incoming webhook requests, every webhook request must carry a form field **Token** in the post body or url query that matches the value


:path: The path portion of the webhook url, by default :code:`/jira`

:jira_domain: Specify the jira domain, e.g. :code:`mycompany` for :code:`mycompany.atlassian.net`

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

This function will create a jira ticket with given information


**Input Contexts**

:jira_project: The name of the jira project the ticket is created in

:ticket_title: A summary of the ticket

:ticket_desc: Detailed description of the work for this ticket

:ticket_type: The ticket type, by default :code:`Task`

**Export Contexts**

:jira_ticket: The ticket number of the newly created ticket

See below for example

.. code-block:: yaml

   ---
   workflows:
     create_jira_ticket:
       call_function: jira.createTicket
       with:
         jira_project: devlops
         ticket_title: upgrading kubernetes
         ticket_desc: |
           Upgrade the test cluster to kubernetes 1.16
   

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
   

notify
------

send chat message through chat system

**Input Contexts**

:chat_system: A system name that supports :code:`reply` and :code:`say` function, can be either :code:`slack` or :code:`slack_bot`, by default :code:`slack_bot`.


:notify: A list of channels to which the message is beng sent, a special name :code:`reply` means replying to the slashcommand user.


:notify_on_error: A list of additional channels to which the message is beng sent if the message_type is error or failure.


:message_type: The type of the message used for coloring, could be :code:`success`, :code:`failure`, :code:`error`, :code:`normal`, :code:`warning`, or :code:`announcement`


:chat_colors: A map from message_type to color codes. This should usually be defined in default context so it can be shared.


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


:env: A list of environment variables for all the steps.


:volumes: A list of volumes to be attached for all the steps. By default, there will be a :code:`EmptyDir` volume attached at :code:`/honeydipper`. Each item should have a `name` and `volume` and optionally a `subPath`, and they will be used for creating the volume definition and volume mount definition.


:workingDir: The working directory in which the command or script to be exected. By default, :code:`/honeydipper`. Note that, the default :code:`workingDir` defined in the image is not used here.


:script_types: A map of predefined script types. The :code:`type` field in :code:`steps` will be used to select the image here. :code:`image` field is required. :code:`command_entry` is used for defining the entrypoint when using :code:`command` field in step, and :code:`command_prefix` are a list or a string that inserted at the top of container args. Correspondingly, the :code:`shell_entry` and :code:`shell_prefix` are used for defining the entrypoint and argument prefix for running a `shell` script.
Also supported is an optional :code:`securtyContext` field for defining the image security context.


:predefined_steps: A map of predefined steps. Use the name of the predefined step in :code:`steps` list to easily define a step without specifying the fields. This makes it easier to repeat or share the steps that can be used in multiple places. We can also override part of the predefined steps when defining the steps with `use` and overriding fields.


:predefined_env: A map of predefined environment variables.


:predefined_volumes: A map of predefined volumes.


:nodeSelector: See k8s pod specification for detail

:affinity: See k8s pod specification for detail

:tolerations: See k8s pod specification for detail

:timeout: Used for setting the :code:`activeDeadlineSeconds` for the k8s pod

:cleanupAfter: Used for setting the :code:`TTLSecondsAfterFinished` for the k8s job, requires 1.13+ and the feature to be enabled for the cluster.


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

This workflow sends a announcement message to the channels listed in :code:`slash_notify`.  Used internally.


slashcommand/help
-----------------

This workflow sends a list of supported commands to the requestor.  Used internally.


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
   

