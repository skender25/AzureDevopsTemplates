terraform {
  required_providers {
    azuredevops = {
      source = "microsoft/azuredevops"
      version = ">=0.2.1"
    }
      azurerm = {
      source = "hashicorp/azurerm"
      version = "~>3.61.0"
    }
  }
}

locals {
  project_id = var.project_exists == true ? data.azuredevops_project.tfprj[0].id : azuredevops_project.tfprj[0].id
  agent_pool_compilacion = var.default_pools_exists == true ? data.azuredevops_agent_pool.pool_compilacion[0].name : var.prefix
  ansible_keys_id = var.needsIaCvariable == false ? null : var.create_IaC_variables == true ? azuredevops_variable_group.var_group_ansible_keys[0].id  : data.azuredevops_variable_group.var_group_ansible_keys[0].id
}


#PPROYECTO

resource "azuredevops_project" "tfprj" {
  count = var.project_exists == true ? 0 : 1
  name = var.project_name
  description  = var.project_description
  visibility = "private"
  version_control = "Git"
  work_item_template = "Basic"
   features = {
       "boards" = "disabled"
       "testplans" = "disabled"
       "artifacts" = "disabled"
   }
}

data "azuredevops_project" "tfprj" {
  count = var.project_exists == true ? 1 : 0
  name = var.project_name
}

data "azuredevops_git_repository" "repo" {
  project_id     = local.project_id
  name           = var.project_name
}

#Pools de agentes

#Pool Default de agentes de compilación y despliegue - INICIO

data "azuredevops_agent_pool" "pool_compilacion" {
  count = var.default_pools_exists == true ? 1 : 0
  name = var.prefix
}

resource "azuredevops_agent_pool" "pool_compilacion" {
  count = var.default_pools_exists == true ? 0 : 1 
  name           = var.prefix
  auto_provision = false
}

resource "azuredevops_agent_queue" "pool_compilacion_queue" {
  count = var.default_pools_exists == true ? 0 : 1
  project_id    = local.project_id
  agent_pool_id = azuredevops_agent_pool.pool_compilacion[0].id
}

resource "azuredevops_resource_authorization" "authorization_pool_compilacion_queue" {
  count = var.default_pools_exists == true ? 0 : 1
  project_id  = local.project_id
  resource_id = azuredevops_agent_queue.pool_compilacion_queue[0].id
  type        = "queue"
  authorized  = true
}

resource "azuredevops_agent_pool" "pool_despliegue_no_prod" {
  count          = var.default_pools_exists == true ? 0 : 1 
  name           = "${var.prefix}-DEV"
  auto_provision = false
  pool_type      = "deployment"
}

resource "azuredevops_agent_pool" "pool_despliegue_prod" {
  count          = var.default_pools_exists == true ? 0 : 1 
  name           = "${var.prefix}-PROD"
  auto_provision = false
  pool_type      = "deployment"
}


#Pool Default de agentes de compilación y despliegue - FIN

#Pool agentes para IaC - INICIO

data "azuredevops_agent_pool" "pool_devops_desa" {
  count = var.create_IaC_pools == true ? 1 : 0 
  name = "Devops-Desa"
}

data "azuredevops_agent_pool" "pool_devops_prod" {
  count = var.create_IaC_pools == true ? 1 : 0 
  name = "Devops-Prod"
}

resource "azuredevops_agent_queue" "agent_desa_queue" {
  count = var.create_IaC_pools == true ? 1 : 0 
  project_id    = local.project_id
  agent_pool_id = data.azuredevops_agent_pool.pool_devops_desa[0].id
}

resource "azuredevops_agent_queue" "agent_prod_queue" {
  count = var.create_IaC_pools == true ? 1 : 0   
  project_id    = local.project_id
  agent_pool_id = data.azuredevops_agent_pool.pool_devops_prod[0].id
}

resource "azuredevops_resource_authorization" "authorization_desa" {
  count = var.create_IaC_pools == true ? 1 : 0 
  project_id  = local.project_id
  resource_id = azuredevops_agent_queue.agent_desa_queue[0].id
  type        = "queue"
  authorized  = true
}

resource "azuredevops_resource_authorization" "authorization_prod" {
  count = var.create_IaC_pools == true ? 1 : 0 
  project_id  = local.project_id
  resource_id = azuredevops_agent_queue.agent_prod_queue[0].id
  type        = "queue"
  authorized  = true
}

#Pool agentes para IaC - FIN


data "azuredevops_variable_group" "existing_var_group" {
  project_id = "e34c4d32-f3e3-49bc-9642-520b6301e9db"
  name       = "ANSIBLE-KEYS"
}
# crea las variables grupo para los pipelines 
resource "azuredevops_variable_group" "var_group_ansible_keys" {
count = var.create_IaC_variables == true ? 1 : 0 
 project_id = local.project_id
 name = "ANSIBLE-KEYS"
 description = "Grupo de variable para ansible linea base"
 allow_access = true
 
  variable {
    name = "ip_server_ansible"
    value = "10.128.0.23"
  }
   variable {
    name = "host_ansible_prod"
    value = "https://vmcriprodansap01.bacnet.corp.redbac.com"
  }

  variable {
    name = "user_ansible_tower"
    value = "devopsdes"
  }
 
  variable {
    name = "password_ansible_tower"
    secret_value = var.password_ansible_tower
    is_secret = true
  }
  
  variable {
    name = "user_server_ansible"
    value = "azbacadmin"
  }

  variable {
    name = "password_server_ansible"
    secret_value = var.password_server_ansible
    is_secret = true
  }
}

data "azuredevops_variable_group" "var_group_ansible_keys" {
  count = var.create_IaC_variables == true ? 0 : var.needsIaCvariable == true ? 1 : 0
  project_id = local.project_id
  name = "ANSIBLE-KEYS"
}

#Crea los environments requeridos proyectos ansible

resource "azuredevops_environment" "ansible_environment_desa" {
  count = var.create_ansible_environmnets == true ? 1 : 0
  project_id = local.project_id
  name       = "Ansible_DESA"
}

resource "azuredevops_environment" "ansible_environment_stg" {
  count = var.create_ansible_environmnets == true ? 1 : 0
  project_id = local.project_id
  name       = "Ansible_STG"
}

#crea las variables de grupo para los pipelines proyectos ansible

resource "azuredevops_variable_group" "vargroup_proyecto_ansible_keys" {
 count = var.create_ansible_keys == true ? 1 : 0 
 project_id = local.project_id
 name = "ANSIBLE-KEYS"
 description = "Grupo de variable para ansible"
 allow_access = true
 
  variable {
    name = "password_ansible_tower"
    secret_value = ""
    is_secret = true
  }
  
  variable {
    name = "password_server_ansible"
    secret_value = ""
    is_secret = true
  }

  variable {
    name = "password_ansible_tower2"
    secret_value = ""
    is_secret = true
  }

}

#crea loss variables de grupo para los pipelines proyectos ansible

resource "azuredevops_serviceendpoint_ssh" "service_conection_desa" {
  count = var.create_ansible_service_conection == true ? 1 : 0
  project_id            = local.project_id
  service_endpoint_name = "ansible_desa_ssh"
  host                  = "10.128.64.81"
  username              = "azbacadmin"
  description           = "Conexión ssh ansible desarrollo"
}

resource "azuredevops_serviceendpoint_ssh" "service_conection_stag" {
  count = var.create_ansible_service_conection == true ? 1 : 0
  project_id            = local.project_id
  service_endpoint_name = "ansible_stg_ssh"
  host                  = "10.128.64.84"
  username              = "azbacadmin"
  description           = "Conexión ssh ansible staging"
}

resource "azuredevops_serviceendpoint_ssh" "service_conection_prod" {
  count = var.create_ansible_service_conection == true ? 1 : 0
  project_id            = local.project_id
  service_endpoint_name = "ansible_prod_ssh"
  host                  = "10.128.0.23"
  username              = "azbacadmin"
  description           = "Conexión ssh ansible produccion"
}


resource "azuredevops_project_pipeline_settings" "tfprj_pipeline_settings" {
  count = var.project_exists == true ? 0 : 1
  project_id = local.project_id
  enforce_job_scope = false
  enforce_referenced_repo_scoped_token = false
  enforce_settable_var = false
  publish_pipeline_metadata = false
  status_badges_are_private = false
}