Gcloud
******

Contains drivers that interactive with gcloud assets

Installation
============

Include the following section in your **init.yaml** under **repos** section

.. code-block:: yaml

   - repo: https://github.com/honeydipper/honeydipper-config-essentials
     branch: DipperCL
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
   

Workflows
=========

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
   

