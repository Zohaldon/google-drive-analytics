# frozen_string_literal: true

require_relative 'google_oauth'
require 'faraday'
require 'json'

module AuthConstant
  ACCESS_TOKEN = '<<token_goes_here>>'
end

module DriveFetcher
  class SharedDriveService
    def initialize(token)
      @token = token
    end

    def collect_info_about_shared_drive
      page_token = nil
      shared_drive_data_collector = { "shared_drive_count": 0, "shared_drives": [] }

      loop do
        response = fetch_drive_info(page_token)
        break if response.nil?

        parsed_response_hash = JSON.parse(response.body)
        log_error('API CALL - collect_info_about_shared_drive', response.body) if response.status != 200

        collect_drive_data(shared_drive_data_collector, parsed_response_hash)

        page_token = parsed_response_hash['nextPageToken']
      end

      dump_data_to_json(shared_drive_data_collector)
    end

    private

    def log_error(subject, response)
      File.open('./error.log', 'a') do |f|
        f.write("Error: #{subject} - #{response}")
      end
    end

    def fetch_drive_info(page_token)
      response = faraday_drive_client.get do |req|
        req.params['pageToken'] = page_token unless page_token.nil?
      end

      if response.status == 429
        sleep(60)
        return nil
      end

      response
    end

    def faraday_drive_client
      Faraday.new(
        url: 'https://www.googleapis.com/drive/v3/drives',
        params: { pageSize: 100 },
        headers: {
          'Content-Type': 'application/json',
          'Authorization': "Bearer #{@token}"
        }
      )
    end

    def collect_drive_data(shared_drive_data_collector, shared_drive_list)
      return if shared_drive_list['drives'].blank?

      shared_drive_list['drives'].each do |drive|
        shared_drive_data_collector[:shared_drive_count] += 1
        drive_id = drive['id']
        permission_info = get_permission_info(drive_id)
        shared_drive_data_collector[:shared_drives].append({ "drive_id": drive_id, "permission_info": permission_info })
      end
    end

    def get_permission_info(drive_id)
      page_token = nil
      data_collector = { owner_count: 0, user_with_access: 0 }

      loop do
        response = fetch_permission_info(drive_id, page_token)
        break if response.nil?

        log_error('API CALL - get_permission_info', response.body) if response.status != 200

        parsed_response_hash = JSON.parse(response.body)
        page_token = parsed_response_hash['nextPageToken']
        collect_drive_permission_data(data_collector, parsed_response_hash)
      end

      data_collector
    end

    def fetch_permission_info(drive_id, page_token)
      response = faraday_drive_permission_client(drive_id).get do |req|
        req.params['pageToken'] = page_token unless page_token.nil?
      end

      if response.status == 429
        sleep(60)
        return nil
      end

      response
    end

    def faraday_drive_permission_client(drive_id)
      Faraday.new(
        url: "https://www.googleapis.com/drive/v3/files/#{drive_id}/permissions",
        params: { pageSize: 100, supportsAllDrives: true, fields: '*' },
        headers: {
          'Content-Type': 'application/json',
          'Authorization': "Bearer #{@token}"
        }
      )
    end

    def collect_drive_permission_data(data_collector, permission_list)
      permissions = permission_list['permissions']
      return if permissions.blank?

      permissions.each do |p|
        data_collector[:user_with_access] += 1
        data_collector[:owner_count] += 1 if p['role'] == 'organizer'
      end
    end

    def dump_data_to_json(shared_drive_data_collector)
      File.open('./shared_drive.json', 'w') do |f|
        f.write(JSON.pretty_generate(shared_drive_data_collector))
      end
    end
  end

  class SharedDriveFileService
    def collect_file_info_for_shared_drive
      shared_drives_json = JSON.parse(File.read('shared_drive.json'))

      return if shared_drives_json['shared_drives'].empty?

      shared_drives_json['shared_drives'].each do |drive|
        drive_id = drive['drive_id']
        data_collector = {
          "shared_drive_id": drive_id,
          "total_size_in_bytes": 0,
          "file_count": 0,
          "folder_count": 0,
          "files": []
        }
        get_files_for_shared_drive(drive_id, AuthConstant::ACCESS_TOKEN, data_collector)
      end
    end

    private

    def get_files_for_shared_drive(drive_id, access_token, data_collector)
      page_token = nil

      loop do
        response = fetch_file_list(drive_id, page_token)

        break if response.nil?

        if response.status == 200
          collect_file_data(data_collector, JSON.parse(response.body))
        else
          log_error('API CALL', response.body)
        end

        page_token = JSON.parse(response.body)['nextPageToken']
      end

      dump_data_to_json(data_collector)
    end

    def fetch_file_list(drive_id, page_token)
      response = faraday_file_list_client(drive_id).get do |req|
        req.params['pageToken'] = page_token unless page_token.nil?
      end

      if response.status == 429
        sleep(60)
        return nil
      end

      response
    end

    def faraday_file_list_client(drive_id)
      Faraday.new(
        url: 'https://www.googleapis.com/drive/v3/files',
        params: {
          corpora: 'drive',
          driveId: drive_id,
          pageSize: 1000,
          fields: '*',
          includeItemsFromAllDrives: true,
          supportsAllDrives: true,
          orderBy: 'createdTime'
        },
        headers: {
          'Content-Type': 'application/json',
          'Authorization': "Bearer #{access_token}"
        }
      )
    end

    def collect_file_data(files_data_collector, file_list)
      return if file_list['files'].blank?

      file_list['files'].each do |file|
        files_data_collector[:file_count] += 1
        files_data_collector[:total_size_in_bytes] += file['size'].to_i
        files_data_collector[:folder_count] += 1 if file['mimeType'] == 'application/vnd.google-apps.folder'
        file_data_collector = file_metadata_template
        file_metadata = scrap_file_metadata(file_data_collector, file)
        files_data_collector[:files].append(file_metadata)
      end
    end

    def dump_data_to_json(collected_data)
      File.open("./shared_drive/#{collected_data[:shared_drive_id]}.json", 'w') do |f|
        f.write(JSON.pretty_generate(collected_data))
      end
    end

    def file_metadata_template
      {
        "file_id": nil,
        "mime_type": nil,
        "full_file_extension": nil,
        "quota_bytes_used": 0,
        "size": 0,
        "is_file_shared": false,
        "total_user_with_access": 0,
        "versions": 0
      }
    end

    def scrap_file_metadata(file_data_collector, file)
      file_data_collector[:file_id] = file['id']
      file_data_collector[:mime_type] = file['mimeType']
      file_data_collector[:full_file_extension] = file['fullFileExtension']
      file_data_collector[:quota_bytes_used] = file['quotaBytesUsed'].to_i
      file_data_collector[:size] = file['size'].nil? ? file['quotaBytesUsed'].to_i : file['size'].to_i
      file_data_collector[:is_file_shared] = file['hasAugmentedPermissions']
      file_data_collector[:total_user_with_access] = file['permissionIds'].length
      file_data_collector[:versions] = file['version']

      file_data_collector
    end

    def log_error(subject, response)
      File.open('./error.log', 'a') do |f|
        f.write("Error: #{subject} - #{response}")
      end
    end
  end
end

def collect_shared_drives
  shared_drive_client = DriveFetcher::SharedDriveService.new(AuthConstant::ACCESS_TOKEN)
  shared_drive_client.collect_info_about_shared_drive
end

def collect_files_for_shared_drives
  shared_drive_file_client = DriveFetcher::SharedDriveFileService.new
  shared_drive_file_client.collect_file_info_for_shared_drive
end

if __FILE__ == $PROGRAM_NAME
  collect_shared_drives
  collect_files_for_shared_drives
end
