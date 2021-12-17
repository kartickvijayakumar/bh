class GrpcServiceGenerator
  include Sidekiq::Worker

  def perform service_id = nil, action = nil
    Rails.logger.debug "===== GrpcServiceGenerator.perform - service.id:#{service_id}, action:#{action}"
    case action
    when 'create'
        GrpcServiceGenerator.initiate_service(service_id)
    when 'import'
      GrpcServiceGenerator.import_service(service_id)
    when 'delete'
        GrpcServiceGenerator.delete_service(service_id)
    when 'deploy'
      GrpcServiceGenerator.deploy_service(service_id)
    when 'destroy'
      GrpcServiceGenerator.destroy_service(service_id)
    else
      # type code here
    end
  end

  def self.import_service(service_id)
    service = Service.find_by_id(service_id)
    return if service.nil? || service.status != Service::STATUSES['NOT_INITIATED']

    service.import_service
  end

  def self.initiate_service(service_id)
    service = Service.find_by_id(service_id)
    return if service.nil? || service.status != Service::STATUSES['NOT_INITIATED']

    service.create_service
  end

  def self.delete_service(service_id)
    service = Service.find_by_id(service_id)
    return if service.nil?

    service.delete_service
  end

  def self.deploy_service(service_id)
    service = Service.find_by_id(service_id)
    puts service.inspect
    return if service.nil?

    service.deploy_service
  end

  def self.destroy_service(service_id)
    service = Service.find_by_id(service_id)
    return if service.nil?

    service.destroy_service
  end
end
