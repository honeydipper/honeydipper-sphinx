Gcloud
******

Contains drivers that interactive with gcloud assets

Installation
============

Include the following section in your **init.yaml** under **repos** section

.. code-block:: yaml

   - repo: https://github.com/honeydipper/honeydipper-config-essentials
     branch: main
     path: /gcloud

Drivers
=======

This repo provides following drivers

gcloud-dataflow
---------------

This driver enables Honeydipper to run dataflow jobs

Action: createJob
^^^^^^^^^^^^^^^^^

creating a dataflow job using a template

**Parameters**

:service_account: A gcloud service account key (json) stored as byte array

:project: The name of the project where the dataflow job to be created

:location: The region where the dataflow job to be created

:job: The specification of the job see gcloud dataflow API reference `CreateJobFromTemplateRequest <https://godoc.org/google.golang.org/api/dataflow/v1b3#CreateJobFromTemplateRequest>`_ for detail


**Returns**

:job: The job object, see gcloud dataflow API reference `Job <https://godoc.org/google.golang.org/api/dataflow/v1b3#Job>`_ for detail


See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     start_dataflow_job:
       call_driver: gcloud-dataflow.createJob
       with:
         service_account: ...masked...
         project: foo
         location: us-west1
         job:
           gcsPath: ...
           ...
   

Action: updateJob
^^^^^^^^^^^^^^^^^

updating a job including draining or cancelling

**Parameters**

:service_account: A gcloud service account key (json) stored as byte array

:project: The name of the project where the dataflow job to be created

:location: The region where the dataflow job to be created

:jobSpec: The updated specification of the job see gcloud dataflow API reference `Job <https://godoc.org/google.golang.org/api/dataflow/v1b3#Job>`_ for detail


:jobID: The ID of the dataflow job

**Returns**

:job: The job object, see gcloud dataflow API reference `Job <https://godoc.org/google.golang.org/api/dataflow/v1b3#Job>`_ for detail


See below for a simple example of draining a job

.. code-block:: yaml

   ---
   workflows:
     find_and_drain_dataflow_job:
       with:
         service_account: ...masked...
         project: foo
         location: us-west1
       steps:
         - call_driver: gcloud-dataflow.findJobByName
           with:
             name: bar
         - call_driver: gcloud-dataflow.updateJob
           with:
             jobID: $data.job.Id
             jobSpec:
               currentState: JOB_STATE_DRAINING
         - call_driver: gcloud-dataflow.waitForJob
           with:
             jobID: $data.job.Id
   

Action: waitForJob
^^^^^^^^^^^^^^^^^^

This action will block until the dataflow job is in a terminal state.

**Parameters**

:service_account: A gcloud service account key (json) stored as byte array

:project: The name of the project where the dataflow job to be created

:location: The region where the dataflow job to be created

:jobID: The ID of the dataflow job

:interval: The interval between polling calls go gcloud API, 15 seconds by default

:timeout: The total time to wait until the job is in terminal state, 1800 seconds by default

**Returns**

:job: The job object, see gcloud dataflow API reference `Job <https://godoc.org/google.golang.org/api/dataflow/v1b3#Job>`_ for detail


See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     run_dataflow_job:
       with:
         service_account: ...masked...
         project: foo
         location: us-west1
       steps:
         - call_driver: gcloud-dataflow.createJob
           with:
             job:
               gcsPath: ...
               ...
         - call_driver: gcloud-dataflow.waitForJob
           with:
             interval: 60
             timeout: 600
             jobID: $data.job.Id
   

Action: findJobByName
^^^^^^^^^^^^^^^^^^^^^

This action will find an active  job by its name

**Parameters**

:service_account: A gcloud service account key (json) stored as byte array

:project: The name of the project where the dataflow job to be created

:location: The region where the dataflow job to be created

:name: The name of the job to look for

**Returns**

:job: A partial job object, see gcloud dataflow API reference `Job <https://godoc.org/google.golang.org/api/dataflow/v1b3#Job>`_ for detail, only :code:`Id`, :code:`Name` and :code:`CurrentState` fields are populated


See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     find_and_wait_dataflow_job:
       with:
         service_account: ...masked...
         project: foo
         location: us-west1
       steps:
         - call_driver: gcloud-dataflow.findJobByName
           with:
             name: bar
         - call_driver: gcloud-dataflow.waitForJob
           with:
             jobID: $data.job.Id
   

Action: waitForJob
^^^^^^^^^^^^^^^^^^

This action will block until the dataflow job is in a terminal state.

**Parameters**

:service_account: A gcloud service account key (json) stored as byte array

:project: The name of the project where the dataflow job to be created

:location: The region where the dataflow job to be created

:jobID: The ID of the dataflow job

:interval: The interval between polling calls go gcloud API, 15 seconds by default

:timeout: The total time to wait until the job is in terminal state, 1800 seconds by default

**Returns**

:job: The job object, see gcloud dataflow API reference `Job <https://godoc.org/google.golang.org/api/dataflow/v1b3#Job>`_ for detail


See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     wait_for_dataflow_job:
       with:
         service_account: ...masked...
         project: foo
         location: us-west1
       steps:
         - call_driver: gcloud-dataflow.createJob
           with:
             job:
               gcsPath: ...
               ...
         - call_driver: gcloud-dataflow.waitForJob
           with:
             interval: 60
             timeout: 600
             jobID: $data.job.Id
   

Action: getJob
^^^^^^^^^^^^^^

This action will get the current status of the dataflow job

**Parameters**

:service_account: A gcloud service account key (json) stored as byte array

:project: The name of the project where the dataflow job to be created

:location: The region where the dataflow job to be created

:jobID: The ID of the dataflow job

**Returns**

:job: The job object, see gcloud dataflow API reference `Job <https://godoc.org/google.golang.org/api/dataflow/v1b3#Job>`_ for detail


See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     query_dataflow_job:
       with:
         service_account: ...masked...
         project: foo
         location: us-west1
       steps:
         - call_driver: gcloud-dataflow.createJob
           with:
             job:
               gcsPath: ...
               ...
         - call_driver: gcloud-dataflow.getJob
           with:
             jobID: $data.job.Id
   

gcloud-gke
----------

This driver enables Honeydipper to interact with GKE clusters.


Honeydipper interact with k8s clusters through :code:`kubernetes` driver. However, the :code:`kubernetes` driver needs to obtain kubeconfig information such as credentials, certs, API endpoints etc. This is achieved through making a RPC call to k8s type drivers. This driver is one of the k8s type driver.


RPC: getKubeCfg
^^^^^^^^^^^^^^^^^^

Fetch kubeconfig information using the vendor specific credentials

**Parameters**

:service_account: Service account key stored as bytes

:project: The name of the project the cluster belongs to

:location: The location of the cluster

:regional: Boolean, true for regional cluster, otherwise zone'al cluster

:cluster: The name of the cluster

**Returns**

:Host: The endpoint API host

:Token: The access token used for k8s authentication

:CACert: The CA cert used for k8s authentication

See below for an example usage on invoking the RPC from k8s driver


.. code:: go

   func getGKEConfig(cfg map[string]interface{}) *rest.Config {
     retbytes, err := driver.RPCCall("driver:gcloud-gke", "getKubeCfg", cfg)
     if err != nil {
       log.Panicf("[%s] failed call gcloud to get kubeconfig %+v", driver.Service, err)
     }

     ret := dipper.DeserializeContent(retbytes)

     host, _ := dipper.GetMapDataStr(ret, "Host")
     token, _ := dipper.GetMapDataStr(ret, "Token")
     cacert, _ := dipper.GetMapDataStr(ret, "CACert")

     cadata, _ := base64.StdEncoding.DecodeString(cacert)

     k8cfg := &rest.Config{
       Host:        host,
       BearerToken: token,
     }
     k8cfg.CAData = cadata

     return k8cfg
   }


To configure a kubernetes cluster in Honeydipper configuration yaml :code:`DipperCL`

.. code-block:: yaml

   ---
   systems:
     my-gke-cluster:
       extends:
         - kubernetes
       data:
         source:  # all parameters to the RPC here
           type: gcloud-gke
           service_account: ...masked...
           project: foo
           location: us-central1-a
           cluster: my-gke-cluster
   

Or, you can share some of the fields by abstracting

.. code-block:: yaml

   ---
   systems:
     my-gke:
       data:
         source:
           type: gcloud-gke
           service_account: ...masked...
           project: foo
   
     my-cluster:
       extends:
         - kubernetes
         - my-gke
       data:
         source:  # parameters to the RPC here
           location: us-central1-a
           cluster: my-gke-cluster
   

gcloud-kms
----------

This driver enables Honeydipper to interact with gcloud KMS to descrypt configurations.


In order to be able to store sensitive configurations encrypted at rest, Honeydipper needs to be able to decrypt the content. :code:`DipperCL` uses e-yaml style notion to store the encrypted content, the type of the encryption and the payload/parameter is enclosed by the square bracket :code:`[]`. For example.


.. code-block:: yaml

   mydata: ENC[gcloud-kms,...base64 encoded ciphertext...]
   

**Configurations**

:keyname: The key in KMS key ring used for decryption. e.g. :code:`projects/myproject/locations/us-central1/keyRings/myring/cryptoKeys/mykey`

RPC: decrypt
^^^^^^^^^^^^^^^

Decrypt the given payload

**Parameters**

:*: The whole payload is used as a byte array of ciphertext

**Returns**

:*: The whole payload is a byte array of plaintext

See below for an example usage on invoking the RPC from another driver


.. code:: go

   retbytes, err := driver.RPCCallRaw("driver:gcloud-kms", "decrypt", cipherbytes)


gcloud-pubsub
-------------

This driver enables Honeydipper to receive and consume gcloud pubsub events


**Configurations**

:service_account: The gcloud service account key (json) in bytes. This service account needs to have proper permissions to subscribe to the topics.


For example

.. code-block:: yaml

   ---
   drivers:
     gcloud-pubsub:
       service-account: ENC[gcloud-gke,...masked...]
   

Event: <default>
^^^^^^^^^^^^^^^^^

An pub/sub message is received

**Returns**

:project: The gcloud project to which the pub/sub topic belongs to

:subscriptionName: The name of the subscription

:text: The payload of the message, if not json

:json: The payload parsed into as a json object

See below for an example usage

.. code-block:: yaml

   ---
   rules:
     - when:
         driver: gcloud-pubsub
         if_match:
           project: foo
           subscriptionName: mysub
           json:
             datakey: hello
       do:
         call_workflow: something
   

gcloud-secret
-------------

This driver enables Honeydipper to fetch items stored in Google Secret Manager.


With access to Google Secret Manager, Honeydipper doesn't have to rely on cipher texts stored directly into the configurations in the repo. Instead, it can query the Google Secret Manager, and get access to the secrets based on the permissions granted to the identity it uses. :code:`DipperCL` uses a keyword interpolation to detect the items that need to be looked up using :code:`LOOKUP[<driver>,<key>]`. See blow for example.


.. code-block:: yaml

   mydata: LOOKUP[gcloud-secret,projects/foo/secrets/bar/versions/latest]
   

As of now, the driver doesn't take any configuration other than the generic `api_timeout`. It uses the default service account as its identity.


RPC: lookup
^^^^^^^^^^^^^^

Lookup a secret in Google Secret Manager

**Parameters**

:*: The whole payload is used as a byte array of string for the key

**Returns**

:*: The whole payload is a byte array of plaintext

See below for an example usage on invoking the RPC from another driver


.. code:: go

   retbytes, err := driver.RPCCallRaw("driver:gcloud-secret", "lookup", []byte("projects/foo/secrets/bar/versions/latest"))


gcloud-spanner
--------------

This driver enables Honeydipper to perform administrative tasks on spanner databases


You can create systems to ease the use of this driver.

for example

.. code-block:: yaml

   ---
   systems:
     my_spanner_db:
       data:
         serivce_account: ENC[...]
         project: foo
         instance: dbinstance
         db: bar
       functions:
         start_backup:
           driver: gcloud-spanner
           rawAction: backup
           parameters:
             service_account: $sysData.service_account
             project: $sysData.foo
             instance: $sysData.dbinstance
             db: $sysData.db
             expires: $?ctx.expires
           export_on_success:
             backupOpID: $data.backupOpID
         wait_for_backup:
           driver: gcloud-spanner
           rawAction: waitForBackup
           parameters:
             backupOpID: $ctx.backupOpID
           export_on_success:
             backup: $data.backup
   

Now we can just easily call the system function like below

.. code-block:: yaml

   ---
   workflows:
     create_spanner_backup:
       steps:
         - call_function: my_spanner_db.start_backup
         - call_function: my_spanner_db.wait_for_backup
   

Action: backup
^^^^^^^^^^^^^^

creating a native backup of the specified database

**Parameters**

:service_account: A gcloud service account key (json) stored as byte array

:project: The name of the project where the dataflow job to be created

:instance: The spanner instance of the database

:db: The name of the database

:expires: Optional, defaults to 180 days, the duration after which the backup will expire and be removed. It should be in the format supported by :code:`time.ParseDuration`. See the `document <https://godoc.org/time#ParseDuration>`_ for detail.


**Returns**

:backupOpID: A Honeydipper generated identifier for the backup operation used for getting the operation status

See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     start_spanner_native_backup:
       call_driver: gcloud-spanner.backup
       with:
         service_account: ...masked...
         project: foo
         instance: dbinstance
         db: bar
         expires: 2160h
         # 24h * 90 = 2160h
       export_on_success:
         backupOpID: $data.backupOpID
   

Action: waitForBackup
^^^^^^^^^^^^^^^^^^^^^

wait for backup and return the backup status

**Parameters**

:backupOpID: The Honeydipper generated identifier by `backup` function call

**Returns**

:backup: The backup object returned by API. See `databasepb.Backup <https://godoc.org/google.golang.org/genproto/googleapis/spanner/admin/database/v1#Backup>`_ for detail


See below for a simple example

.. code-block:: yaml

   ---
   workflows:
     wait_spanner_native_backup:
       call_driver: gcloud-spanner.waitForbackup
       with:
         backupOpID: $ctx.backupOpID
   

Systems
=======

dataflow
--------

This system provides a few functions to interact with Google dataflow jobs.


**Configurations**

:service_accounts.dataflow: The service account json key used to access the dataflow API, optional

:locations.dataflow: The default location to be used for new dataflow jobs, if missing will use :code:`.sysData.locations.default`. And, can be overriden using `.ctx.location`


:subnetworks.dataflow: The default subnetwork to be used for new dataflow jobs, if missing will use :code:`.sysData.subnetworks.default`. And, can be overriden using `.ctx.subnetwork`


:project: default project used to access the dataflow API if :code:`.ctx.project` is not provided, optional


The system can share data with a common configuration Google Cloud system that contains the configuration.

For example

.. code-block:: yaml

   ---
   systems:
     dataflow:
       extends:
         - gcloud-config
     gcloud-config:
       project: my-gcp-project
       locations:
         default: us-central1
       subnetworks:
         default: default
       service_accounts:
         dataflow: ENC[gcloud-kms,xxxxxxx]
   

Function: createJob
^^^^^^^^^^^^^^^^^^^

Creates a dataflow job using a template.


**Input Contexts**

:project: Optional, in which project the job is created, defaults to the :code:`project` defined with the system

:location: Optional, the location for the job, defaults to the system configuration

:subnetwork: Optional, the subnetwork for the job, defaults to the system configuration

:job: Required, the data structure describe the :code:`CreateJobFromTemplateRequest`, see the `API document <https://pkg.go.dev/google.golang.org/api/dataflow/v1b3#CreateJobFromTemplateRequest>`_ for details.

**Export Contexts**

:job: The job object, details `here <https://pkg.go.dev/google.golang.org/api/dataflow/v1b3#Job>`_

For example

.. code-block:: yaml

   call_function: dataflow.createJob
   with:
     job:
       gcsPath: gs://dataflow-templates/Cloud_Spanner_to_GCS_Avro
       jobName: export-a-spanner-DB-to-gcs
       parameters:
         instanceId: my-spanner-instance
         databaseId: my-spanner-db
         outputDir: gs://my_spanner_export_bucket
   

Function: findJob
^^^^^^^^^^^^^^^^^

Find an active job with the given name pattern


**Input Contexts**

:project: Optional, in which project the job is created, defaults to the :code:`project` defined with the system

:location: Optional, the location for the job, defaults to the system configuration

:jobNamePattern: Required, a regex pattern used for match the job name

**Export Contexts**

:job: The first active matching job object, details `here <https://pkg.go.dev/google.golang.org/api/dataflow/v1b3#Job>`_

For example

.. code-block:: yaml

   steps:
     - call_function: dataflow.findJob
       with:
         jobNamePattern: ^export-a-spanner-DB-to-gcs$
     - call_function: dataflow.getStatus
   

Function: getStatus
^^^^^^^^^^^^^^^^^^^

Wait for the dataflow job to complete and return the status of the job.


**Input Contexts**

:project: Optional, in which project the job is created, defaults to the :code:`project` defined with the system

:location: Optional, the location for the job, defaults to the system configuration

:job: Optional, the data structure describe the :code:`Job`, see the `API document <https://pkg.go.dev/google.golang.org/api/dataflow/v1b3#Job>`_ for details, if not specified, will use the dataflow job information from previous :code:`createJob` call.

:timeout: Optional, if the job doesn't complete within the timeout, report error, defaults to :code:`1800` seconds

:interval: Optional, polling interval, defaults to :code:`15` seconds

**Export Contexts**

:job: The job object, details `here <https://pkg.go.dev/google.golang.org/api/dataflow/v1b3#Job>`_

For example

.. code-block:: yaml

   steps:
     - call_function: dataflow.createJob
       with:
         job:
           gcsPath: gs://dataflow-templates//Cloud_Spanner_to_GCS_Avro
           jobName: export-a-spanner-DB-to-gcs
           parameters:
             instanceId: my-spanner-instance
             databaseId: my-spanner-db
             outputDir: gs://my_spanner_export_bucket
     - call_function: dataflow.getStatus
   

Function: updateJob
^^^^^^^^^^^^^^^^^^^

Update a running dataflow job


**Input Contexts**

:project: Optional, in which project the job is created, defaults to the :code:`project` defined with the system

:location: Optional, the location for the job, defaults to the system configuration

:jobSpec: Required, a job object with a :code:`id` and the fields for updating.

For example

.. code-block:: yaml

   steps:
     - call_function: dataflow.findJob
       with:
         jobNamePattern: ^export-a-spanner-DB-to-gcs$
     - call_function: dataflow.updateJob
       with:
         jobSpec:
           requestedState: JOB_STATE_DRAINING
     - call_function: dataflow.getStatus
   

kubernetes
----------

No description is available for this entry!

Workflows
=========

cancelDataflowJob
-----------------

Cancel an active dataflow job, and wait for the job to quit.

**Input Contexts**

:system: The dataflow system used for draining the job

:job: Required, a job object returned from previous :code:`findJob` or :code:`getStatus` functions, details `here <https://pkg.go.dev/google.golang.org/api/dataflow/v1b3#Job>`_

:cancelling_timeout: Optional, time in seconds for waiting for the job to quit, default 1800

**Export Contexts**

:job: The updated job object, details `here <https://pkg.go.dev/google.golang.org/api/dataflow/v1b3#Job>`_

:reason: If the job fails, the reason for the failure as reported by the API.

For example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: webhook
           trigger: request
       do:
         steps:
           - call_function: dataflow-sandbox.findJob
             with:
               jobNamePatttern: ^my-job-[0-9-]*$
           - call_workflow: cancelDataflowJob
             with:
               system: dataflow-sandbox
               # job object is automatically exported from previous step
   

drainDataflowJob
----------------

Draining an active dataflow job, including finding the job with a regex name pattern, requesting draining and waiting for the job to complete.

**Input Contexts**

:system: The dataflow system used for draining the job

:jobNamePattern: Required, a regex pattern used for match the job name

:draining_timeout: Optional, draining timeout in seconds, default 1800

:no_cancelling: Optional, unless specified, the job will be cancelled after draining timeout

:cancelling_timeout: Optional, time in seconds for waiting for the job to quit, default 1800

**Export Contexts**

:job: The job object, details `here <https://pkg.go.dev/google.golang.org/api/dataflow/v1b3#Job>`_

:reason: If the job fails, the reason for the failure as reported by the API.

For example

.. code-block:: yaml

   ---
   rules:
     - when:
         source:
           system: webhook
           trigger: request
       do:
         call_workflow: drainDataflowJob
         with:
           system: dataflow-sandbox
           jobNamePatttern: ^my-job-[0-9-]*$
   

use_gcloud_kubeconfig
---------------------

This workflow will add a step into :code:`steps` context variable so the following :code:`run_kubernetes` workflow can use :code:`kubectl` with gcloud service account credential


**Input Contexts**

:cluster: A object with :code:`cluster` field and optionally, :code:`project`, :code:`zone`, and :code:`region` fields

The workflow will add a step to run :code:`gcloud container clusters get-credentials` to populate the kubeconfig file.

.. code-block:: yaml

   ---
   workflows:
     run_gke_job:
       steps:
         - call_workflow: use_google_credentials
         - call_workflow: use_gcloud_kubeconfig
           with:
             cluster:
               cluster: my-cluster
         - call_workflow: run_kubernetes
           with:
             steps+:
               - type: gcloud
                 shell: kubectl get deployments
   

use_google_credentials
----------------------

This workflow will add a step into :code:`steps` context variable so the following :code:`run_kubernetes` workflow can use default google credentials or specify a credential through a k8s secret.


.. important::
   It is recommended to always use this with :code:`run_kubernetes` workflow if :code:`gcloud` steps are used


**Input Contexts**

:google_credentials_secret: The name of the k8s secret storing the service account key, if missing, use default service account

For example

.. code-block:: yaml

   ---
   workflows:
     run_gke_job:
       steps:
         - call_workflow: use_google_credentials
           with:
             google_credentials_secret: my_k8s_secret
         - call_workflow: run_kubernetes
           with:
             steps+:
               - type: gcloud
                 shell: gcloud compute disks list
   

