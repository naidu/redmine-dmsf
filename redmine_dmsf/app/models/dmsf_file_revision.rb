# Redmine plugin for Document Management System "Features"
#
# Copyright (C) 2011   Vít Jonáš <vit.jonas@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class DmsfFileRevision < ActiveRecord::Base
  unloadable
  belongs_to :file, :class_name => "DmsfFile", :foreign_key => "dmsf_file_id"
  belongs_to :source_revision, :class_name => "DmsfFileRevision", :foreign_key => "source_dmsf_file_revision_id"
  belongs_to :user
  belongs_to :folder, :class_name => "DmsfFolder", :foreign_key => "dmsf_folder_id"
  belongs_to :deleted_by_user, :class_name => "User", :foreign_key => "deleted_by_user_id"
  
  acts_as_event :title => Proc.new {|o| "DMSF updated: #{o.file.dmsf_path_str}"},
                :url => Proc.new {|o| {:controller => 'dmsf_detail', :action => 'file_detail', :id => o.file.project, :file_id => o.file}},
                :datetime => Proc.new {|o| o.updated_at },
                :description => Proc.new {|o| o.comment },
                :author => Proc.new {|o| o.user }
                
  acts_as_activity_provider :type => "dmsf_files",
                            :timestamp => "#{DmsfFileRevision.table_name}.updated_at",
                            :author_key => "#{DmsfFileRevision.table_name}.user_id",
                            :permission => :view_dmsf_files,
                            :find_options => {:select => "#{DmsfFileRevision.table_name}.*", 
                                              :joins => 
                                                "INNER JOIN #{DmsfFile.table_name} ON #{DmsfFileRevision.table_name}.dmsf_file_id = #{DmsfFile.table_name}.id " +
                                                "INNER JOIN #{Project.table_name} ON #{DmsfFile.table_name}.project_id = #{Project.table_name}.id",
                                              :conditions => ["#{DmsfFile.table_name}.deleted = :false", {:false => false}]
                                             }
  
  def self.remove_extension(filename)
    filename[0, (filename.length - File.extname(filename).length)]
  end
  
  #TODO: check if better to move to dmsf_upload class
  def self.filename_to_title(filename)
    remove_extension(filename).gsub(/_+/, " ");
  end
  
  def version
    "#{self.major_version}.#{self.minor_version}"
  end

  def project
    self.file.project
  end

  def disk_file
    "#{DmsfFile.storage_path}/#{self.disk_filename}"
  end
  
  def detect_content_type
    content_type = self.mime_type
    content_type = Redmine::MimeType.of(self.disk_filename) if content_type.blank?
    content_type = "application/octet-stream" if content_type.blank?
    content_type.to_s
  end
  
  def from_form_post(file, posted, source_revision = nil)
    source_revision = file.last_revision if source_revision.nil?
    
    self.file = file
    self.source_revision = source_revision
    
    self.name = posted.has_key?("name") ? posted["name"] : self.file.name 
    
    if posted.has_key?("dmsf_folder_id")
      self.folder = posted["dmsf_folder_id"].blank? ? nil : DmsfFolder.find(posted["dmsf_folder_id"])
    else
      self.folder = self.file.folder
    end
    
    if source_revision.nil?
      from_form_post_create(posted)
    else
      from_form_post_existing(posted, source_revision)
    end
    
    self.user = User.current
    self.title = posted["title"]
    self.description = posted["description"]
    self.comment = posted["comment"]
    
    unless posted["file"].nil?
      copy_file_content(posted)
    end

    self
  end
  
  #TODO: use standard clone method
  def clone
    new_revision = DmsfFileRevision.new
    new_revision.file = self.file
    new_revision.disk_filename = self.disk_filename
    new_revision.size = self.size
    new_revision.mime_type = self.mime_type
    new_revision.title = self.title
    new_revision.description = self.description
    new_revision.workflow = self.workflow
    new_revision.major_version = self.major_version
    new_revision.minor_version = self.minor_version
    
    new_revision.source_revision = self
    new_revision.user = User.current
    
    new_revision.name = self.name
    new_revision.folder = self.folder
    
    return new_revision
  end
  
  #TODO: validate if it isn't doubled or move it to view
  def workflow_str
    case workflow
      when 1 then l(:title_waiting_for_approval)
      when 2 then l(:title_approved)
      else nil
    end
  end
  
  def set_workflow(workflow)
    if User.current.allowed_to?(:file_approval, self.file.project)
      self.workflow = workflow
    else
      if self.source_revision.nil?
        self.workflow = workflow == 2 ? 1 : workflow
      else
        if workflow == 2 || self.source_revision.workflow == 1 || self.source_revision.workflow == 2
          self.workflow = 1
        else
          self.workflow = workflow
        end
      end
    end
  end
  
  def increase_version(version_to_increase, new_content)
    if new_content
      self.minor_version = case version_to_increase 
        when 2 then 0
        else self.minor_version + 1
      end
    else
      self.minor_version = case version_to_increase 
        when 1 then self.minor_version + 1
        when 2 then 0
        else self.minor_version
      end
    end

    self.major_version = case version_to_increase 
      when 2 then self.major_version + 1
      else self.major_version
    end
  end
  
  def display_title
    #if self.title.length > 35
    #  return self.title[0, 30] + "..."
    #else 
      return self.title
    #end
  end
  
  def new_storage_filename
    filename = DmsfHelper.sanitize_filename(self.name)
    timestamp = DateTime.now.strftime("%y%m%d%H%M%S")
    while File.exist?(File.join(DmsfFile.storage_path, "#{timestamp}_#{self.id}_#{filename}"))
      timestamp.succ!
    end
    "#{timestamp}_#{id}_#{filename}"
  end
  
  def copy_file_content(file_upload)
    self.disk_filename = self.new_storage_filename
    File.open(self.disk_file, "wb") do |f| 
      while (buffer = file_upload.read(8192))
        f.write(buffer)
      end
    end
    self.size = File.size(self.disk_file)
  end
     
end