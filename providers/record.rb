require 'aws-sdk'

def name
  @name ||= begin
    return new_resource.name + '.' if new_resource.name !~ /\.$/
    new_resource.name
  end
end

def value
  @value ||= Array(new_resource.value)
end

def type
  @type ||= new_resource.type
end

def ttl
  @ttl ||= new_resource.ttl
end

def overwrite?
  @overwrite ||= new_resource.overwrite
end

def mock?
  @mock ||= new_resource.mock
end

def resource_record_set
  {
    name: name,
    type: type,
    ttl: ttl,
    resource_records:
      value.sort.map{|v| {value: v} }
  }
end


def route53
  @route53 ||= begin
    if mock?
      @route53 = Aws::Route53::Client.new(stub_responses: true)
    elsif new_resource.aws_access_key_id && new_resource.aws_secret_access_key
      @route53 = Aws::Route53::Client.new(
        access_key_id: new_resource.aws_access_key_id,
        secret_access_key: new_resource.aws_secret_access_key
      )
    else
      Chef::Log.info "No AWS credentials supplied, going to attempt to use automatic credentials from IAM or ENV"
      @route53 = Aws::Route53::Client.new()
    end
  end
end

def current_resource_record_set
  # List all the resource records for this zone:
  lrrs = route53.
    list_resource_record_sets(hosted_zone_id: "/hostedzone/#{zone}")
  # Select current resource record set by name
  current = lrrs[:resource_record_sets].
    select{ |rr| rr[:name] == name }.first
  # return as hash, converting resource record
  # array of structs to array of hashes
  {
    name: current[:name],
    type: current[:type],
    ttl: current[:ttl],
    resource_records:
      current[:resource_records].sort.map{ |rrr| rrr.to_h }
  }
end

def change_record(action)
  begin
    response = route53.change_resource_record_sets(
      hosted_zone_id: "/hostedzone/#{zone}",
      change_batch: {
        comment: "Chef Route53 Resource: #{name}",
        changes: [
          {
            action: action,
            resource_record_set: resource_record_set
          },
        ],
      },
    )
    Chef::Log.debug "Changed record - #{action}: #{response.inspect}"
  rescue Aws::Route53::Errors::ServiceError => e
    Chef::Log.error e.context
  end
end

action :create do
  if overwrite?
    change_record "UPSERT"
    Chef::Log.info "Record created/modified: #{name}"
  else
    change_record "CREATE"
    Chef::Log.info "Record created: #{name}"
  end
end

action :delete do
  if mock?
    # Make some fake data so that we can successfully delete when testing.
    mock_r_r_set = resource_record_set.dup
    mock_r_r_set[:resource_records] = [ value: '1.2.3.4']
    response = route53.change_resource_record_sets(
      hosted_zone_id: "/hostedzone/#{zone}",
      change_batch: {
        comment: "TestChangeResourceRecordSet",
        changes: [
          {
            action: "CREATE",
            resource_record_set: mock_r_r_set
          },
        ],
      },
    )
  end

  if current_resource_record_set.nil?
    Chef::Log.info 'There is nothing to delete.'
  else
    change_record "DELETE"
    Chef::Log.info "Record deleted: #{name}"
  end
end
