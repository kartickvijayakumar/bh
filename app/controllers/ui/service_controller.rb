class Ui::ServiceController < UiController
  def create
    params['deployment_infrastructure'] ||= 'NOT_APPLICABLE'

    meta = {
      source: "CREATE",
      details: {
        package_name: params['package_name']
      }
    }.to_json

    service = Hub.current.services.create(
      name: params['service_name'],
      cloud_provider: params['cloud_provider'],
      server_prog_language: params['server_prog_language'],
      server_infrastructure: params['server_infrastructure'],
      deployment_infrastructure: params['deployment_infrastructure'],
      meta: meta)

    if service.errors.any?
      flash['warning'] = service.errors.messages.values.flatten
    else
      flash['success'] = 'Service creation is initiated successfully'
    end
    redirect_to ui_home_path
  end

  def destroy
    service = Hub.current.services.find_by(id: params['id'])

    if service.status == Service::STATUSES['DEPLOYED']
      flash['error'] = "Failed to initiate deletion. Service is in DEPLOYED state!"
    else
      service.update!(status: Service::STATUSES['DELETE_INITIATED'])
      GrpcServiceGenerator.perform_async(service.id, 'delete')
      flash['success'] = 'Service deletion initiated successfully'
    end

    redirect_to ui_home_path
  end

  def deploy
    service = Hub.current.services.find_by(id: params['id'])
    puts service.inspect

    if !service.can_deploy?
      flash['error'] = "Failed to initiate deployment. Service is not in CREATED or DESTROYED state!"
    else
      service.update!(status: Service::STATUSES['DEPLOY_INITIATED'])
      GrpcServiceGenerator.perform_async(service.id, 'deploy')
      flash['success'] = 'Service deployment initiated successfully'
    end

    redirect_to ui_home_path
  end

  def destroy_service
    service = Hub.current.services.find_by(id: params['id'])

    # if !service.can_destroy?
    #   flash['error'] = "Failed to initiate destroy. Service is not in DEPLOYED state!"
    # else
      service.update!(status: Service::STATUSES['DESTROY_INITIATED'])
      GrpcServiceGenerator.perform_async(service.id, 'destroy')
      flash['success'] = 'Service destroy initiated successfully'
    # end

    redirect_to ui_home_path
  end

  def import_service
    name = params['name']
    meta = {
      source: "IMPORT",
      details: {
        repo_id: params['repo_id'],
        repo_name: name,
        repo_owner: params['owner'],
        repo_branch: params['branch']
      }
    }.to_json

    service = Hub.current.services.create(
      name: params['name'],
      cloud_provider: Service::CLOUD_PROVIDERS['AWS'],
      server_prog_language: Service::SERVER_PROG_LANGUAGES['Rails'],
      server_infrastructure: Service::SERVER_INFRASTRUCTURES['Fargate'],
      deployment_infrastructure: Service::DEPLOYMENT_INFRASTRUCTURES['CodePipeline'],
      meta: meta)

    if service.errors.any?
      flash['warning'] = service.errors.messages.values.flatten
    else
      flash['success'] = 'Import initiated successfully'
    end
    redirect_to ui_home_path
  end
end
