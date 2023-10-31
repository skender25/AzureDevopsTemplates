output "project_id" {
    value = local.project_id
}

output "agent_pool_compilacion" {
    value = local.agent_pool_compilacion
} 

output "ansible_keys_id" {
    value = local.ansible_keys_id
} 

output "default_repositorio_base_id"{
    value = data.azuredevops_git_repository.repo.id
} 