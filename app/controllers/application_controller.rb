require 'open_assessments'

class ApplicationController < ActionController::Base

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :protect_account
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_account
  helper_method :signif

  protected

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.html { redirect_to root_url, alert: exception.message }
      format.json { render json: {error: exception.message}, status: :unauthorized }
    end
  end

  # **********************************************
  #
  # Utility methods:
  #
  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) << :name
    devise_parameter_sanitizer.for(:account_update) << :name
  end

  def signif(value, signs)
    Float("%.#{signs}g" % value)
  end

  # **********************************************
  #
  # Domain related functionality:
  #
  def get_domain(url)
    url = "http://#{url}" if URI.parse(url).scheme.nil? rescue nil
    host = URI.parse(url).host.downcase rescue nil
    host
  end

  def ensure_scheme(url)
    return nil unless url.present?
    url = "http://#{url}" unless url.starts_with?("http") || url.starts_with?('//:')
    url
  end

  # **********************************************
  #
  # Embed related functionality:
  #
  def embed_url(assessment, query_params={})
    query_params[:format] = 'xml'
    api_assessment_url(assessment, query_params)
  end

  def embed_code(assessment, confidence_levels=true, eid=nil, enable_start=false, offline=false, src_url=nil, style=nil, asid=nil, per_sec=nil, assessment_kind = nil, assessment_title=nil, section_count = nil)
    if assessment
      url = "#{request.host_with_port}#{assessment_path('load')}?src_url=#{embed_url(assessment)}"
    elsif src_url
      url = "#{request.host_with_port}#{assessment_path('load')}?src_url=#{src_url}"
    else
      raise "You must provide an assessment or src_url"
    end
    url << "&results_end_point=#{request.scheme}://#{request.host_with_port}/api"
    url << "&assessment_id=#{assessment.id}" if assessment.present?
    url << "&confidence_levels=true" if confidence_levels.present?
    url << "&eid=#{eid}" if eid.present?
    url << "&enable_start=#{enable_start}" if enable_start.present?
    url << "&offline=true" if offline
    url << "&style=" + style if style.present?
    url << "&asid=" + asid if asid.present?
    url << "&per_sec=" + per_sec if per_sec.present?
    url << "&assessment_kind=" + assessment_kind if assessment_kind.present?
    url << "&assessment_title=" + assessment_title if assessment_title.present?
    url << "&section_count=" + section_count.to_s if section_count.present?

    if assessment
      height = assessment.recommended_height || 575
    else
      height = 575
    end
    CGI.unescapeHTML(%Q{<iframe id="openassessments_container" src="//#{url}" frameborder="0" style="border:none;width:100%;height:100%;min-height:#{height}px;"></iframe>})
  end

  # **********************************************
  #
  # Devise related functionality:
  #
  def after_sign_in_path_for(user)
    user_path(user)
  end

  # **********************************************
  #
  # Tracking related functionality:
  #
  def skip_trackable
    request.env['devise.skip_trackable'] = true
  end

  def tracking_info
    rendered_time = Time.now
    referer = request.env['HTTP_REFERER']
    if !@user = User.find_by(name: request.session.id)
      @user = User.create_anonymous
      @user.name = request.session.id
      @user.external_id = params[:user_id]
      @user.save!
    end
    [rendered_time, referer, @user]
  end

  # **********************************************
  # JWT methods
  #

  class InvalidTokenError < StandardError;
  end

  def validate_token
    begin
      authorization = request.headers['Authorization']
      raise InvalidTokenError if authorization.nil?

      token = request.headers['Authorization'].split(' ').last
      payload, header = AuthToken.valid?(token)

      raise InvalidTokenError if Rails.application.secrets.auth0_client_id != payload["aud"]

      valid_token_callback(payload, header)
      true
    rescue JWT::DecodeError, InvalidTokenError
      render :json => {:error => "Unauthorized: Invalid token."}, status: :unauthorized
      false
    end
  end

  def valid_token_callback(payload, header)
    @user = User.find(payload['user_id'])
    sign_in(@user, :event => :authentication)
  end

  # **********************************************
  # Admin methods
  #
  def check_admin
    if !current_user.admin?
      respond_to do |format|
        format.json {
          render json: {error: "Unauthorized: User not allowed to access requested resource."}, status: :unauthorized
        }
      end
    end
  end

  # **********************************************
  # Paging methods
  #

  def setup_paging
    @page = (params[:page] || 1).to_i
    @page = 1 if @page < 1
    @per_page = (params[:per_page] || (::Rails.env=='test' ? 1 : 40)).to_i
  end

  def set_will_paginate_string
    # Because I18n.locale are dynamically determined in ApplicationController,
    # it should not put in config/initializers/will_paginate.rb
    WillPaginate::ViewHelpers.pagination_options[:previous_label] = "previous"
    WillPaginate::ViewHelpers.pagination_options[:next_label] = "next"
  end

  def setup_will_paginate
    setup_paging
    set_will_paginate_string
  end

  # **********************************************
  #
  # OAuth related functionality:
  #

  def find_consumer
    key = params[:oauth_consumer_key].strip
    Account.find_by(lti_key: key) ||
            User.find_by(lti_key: key)
  end

  def check_external_identifier(user, only_build=false)
    if session[:external_identifier]
      exid = user.external_identifiers.build(:identifier => session[:external_identifier], :provider => session[:provider])
      exid.save! unless only_build
      session[:external_identifier] = nil
      session[:provider] = nil
      exid
    end
  end

  def create_external_identifier_with_url(auth, user)
    json = Yajl::Parser.parse(auth['json_response'])
    key = UrlHelper.host(json['info']['url'])
    user.external_identifiers.create(:identifier => auth.uid, :provider => key) # If they already have an exernal identifier this can just fail silently
  end


  # **********************************************
  #
  # Account related functionality:
  #

  def current_account
    @current_account ||= Account.find_by(code: request.subdomains.first) || Account.find_by(domain: request.host) || Account.main
  end

  def protect_account
    return if ['default', 'sessions', 'devise/passwords', 'devise/confirmations', 'devise/unlocks'].include?(params[:controller])
    return if request.post? && params['lti_message_type'].present?
    user_not_authorized if current_account.restrict_public && !user_signed_in?
  end

  private

  def current_ability
    @current_ability ||= Ability.new(current_user, current_account)
  end

  def user_not_authorized
    render :file => "public/401.html", :status => :unauthorized
  end

  def authenticate_user_from_token!
    auth_token = params[:auth_token].presence
    user = auth_token && User.find_by(authentication_token: auth_token.to_s)

    if user
      # Notice we are passing store false, so the user is not
      # actually stored in the session and a token is needed
      # for every request. If you want the token to work as a
      # sign in token, you can simply remove store: false.
      sign_in user, store: false
    end
  end

end
