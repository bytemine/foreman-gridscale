module ForemanGridscale
  class Gridscale < ComputeResource
    alias_attribute  :api_token, :password
    alias_attribute  :user_uuid, :user
    alias_attribute  :object_uuid, :uuid

    has_one :key_pair, :foreign_key => :compute_resource_id, :dependent => :destroy
    delegate  :to => :client

    # attribute :api_token
    # attribute :user_uuid

    validates :api_token, :user_uuid, :presence => true
    before_create :test_connection


    def api_token
      attrs[:api_token]

    end

    def user_uuid
      attrs[:user_uuid]
    end

    def api_token=(api_token)
      attrs[:api_token] = api_token
    end

    def user_uuid=(user_uuid)
      attrs[:user_uuid] = user_uuid
    end


    def to_label
      "#{name} (#{provider_friendly_name})"
    end

    def provided_attributes
      super.merge(
        :uuid => :server_uuid,
        # :ip => :ipaddr_uuid
        # :ip6 => :ipv6_address
      )
    end

    def get_ip
      client.ips.get(ipaddr_uuid).ip
    end

    def capabilities
      [:build]
    end


    def create_vm(args = {})
      # args['ssh_keys'] = [ssh_key] if ssh_key
      args['cores'] = args['cores'].to_i
      args['memory'] = args['memory'].to_i
      # args['ipaddr_uuid'] = args['ipaddr_uuid']
      # args['network_uuid'] = args['network_uuid']
      Foreman::Logging.logger('foreman_gridscale').info "Initializing docker registry for user #{args['memory']}"
      super(args)
    rescue Fog::Errors::Error => e
      logger.error "Unhandled DigitalOcean error: #{e.class}:#{e.message}\n " + e.backtrace.join("\n ")
      raise e
    end

    def destroy_vm(uuid)
      vm = find_vm_by_uuid(uuid)
      vm.delete if vm.present?
      true
    end

    def ips
      client.ips
    end

    def interfaces
      client.interfaces rescue []
    end

    def networks
      client.networks rescue []
    end
    #
    # def network
    #   client.networks.get(network_uuid)
    # end

    # def ip
    #   client.ips.get(ipaddr_uuid)
    # end

    def self.model_name
      ComputeResource.model_name
    end

    def find_vm_by_uuid(uuid)
      client.servers.get(uuid)
    rescue Fog::Compute::Gridscale::Error
      raise(ActiveRecord::RecordNotFound)
    end

    def test_connection(options = {})
      super
      errors[:token].empty? && errors[:uuid].empty?
    rescue Excon::Errors::Unauthorized => e
      errors[:base] << e.response.body
    rescue Fog::Errors::Error => e
      errors[:base] << e.message
    end

    def default_region_name
      @default_region_name ||= 'de/fra'
    rescue Excon::Errors::Unauthorized => e
      errors[:base] << e.response.body
    end

    def self.provider_friendly_name
      'gridscale'
    end

    def user_data_supported?
      true
    end

    # def new_vm(attr = {})
    #   test_connection
    #   client.servers.new vm_instance_defaults.merge(attr.to_hash.deep_symbolize_keys) if errors.empty?
    # end

    private

    def client
      @client ||= Fog::Compute.new(
          :provider => 'gridscale',
          :api_token => api_token,
          :user_uuid => user_uuid
      )
    end

    def vm_instance_defaults
      super.merge(
          :location_uuid => '45ed677b-3702-4b36-be2a-a2eab9827950'
      )
    end

    # Creates a new key pair for each new Gridscale compute resource
    # After creating the key, it uploads it to Gridscale
    # def setup_key_pair
    #   public_key, private_key = generate_key
    #   key_name = "foreman-#{id}#{Foreman.uuid}"
    #   client.create_ssh_key key_name, public_key
    #   KeyPair.create! :name => key_name, :compute_resource_id => id, :secret => private_key
    # rescue StandardError => e
    #   logger.warn 'failed to generate key pair'
    #   logger.error e.message
    #   logger.error e.backtrace.join("\n")
    #   destroy_key_pair
    #   raise
    # end

    # def destroy_key_pair
    #   return unless key_pair
    #   logger.info "removing Gridscale key #{key_pair.name}"
    #   client.destroy_ssh_key(ssh_key.id) if ssh_key
    #   key_pair.destroy
    #   true
    # rescue StandardError => e
    #   logger.warn "failed to delete key pair from Gridscale, you might need to cleanup manually : #{e}"
    # end

    # def ssh_key
    #   @ssh_key ||= begin
    #     key = client.list_ssh_keys.data[:body]['ssh_keys'].find { |i| i['name'] == key_pair.name }
    #     key['id'] if key.present?
    #   end
    # end

    # def generate_key
    #   key = OpenSSL::PKey::RSA.new 2048
    #   type = key.ssh_type
    #   data = [key.to_blob].pack('m0')
    #
    #   openssh_format_public_key = "#{type} #{data}"
    #   [openssh_format_public_key, key.to_pem]
    # end
  end
end
