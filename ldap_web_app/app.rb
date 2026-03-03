#!/usr/bin/env ruby
# Application web Sinatra de raccordement au serveur LDAP public de test
# Étape 1 du projet : Découverte de LDAP via une interface web

require 'sinatra'
require 'net/ldap'

# --- Configuration ---

LDAP_HOST = 'ldap.forumsys.com'
LDAP_PORT = 389
BASE_DN   = 'dc=example,dc=com'
ADMIN_DN  = "cn=read-only-admin,#{BASE_DN}"
ADMIN_PWD = 'password'

set :port, 4567
set :bind, '0.0.0.0'
set :views, File.join(settings.root, 'views')
set :public_folder, File.join(settings.root, 'public')

enable :sessions

# --- Helpers ---

helpers do
  def ldap_admin
    Net::LDAP.new(
      host: LDAP_HOST,
      port: LDAP_PORT,
      auth: { method: :simple, username: ADMIN_DN, password: ADMIN_PWD }
    )
  end

  def ldap_user(uid, password)
    Net::LDAP.new(
      host: LDAP_HOST,
      port: LDAP_PORT,
      auth: { method: :simple, username: "uid=#{uid},#{BASE_DN}", password: password }
    )
  end

  def fetch_all_users
    ldap = ldap_admin
    return [] unless ldap.bind

    users = []
    filter = Net::LDAP::Filter.eq('objectClass', 'inetOrgPerson')
    ldap.search(base: BASE_DN, filter: filter) do |entry|
      next if entry.dn.include?('read-only-admin')
      users << {
        dn: entry.dn,
        uid: entry.respond_to?(:uid) ? entry.uid.first : 'N/A',
        cn: entry.respond_to?(:cn) ? entry.cn.first : 'N/A',
        mail: entry.respond_to?(:mail) ? entry.mail.first : 'N/A',
        sn: entry.respond_to?(:sn) ? entry.sn.first : 'N/A',
        phone: entry.respond_to?(:telephoneNumber) ? entry.telephoneNumber.first : nil
      }
    end
    users.sort_by { |u| u[:cn] }
  end

  def fetch_groups
    ldap = ldap_admin
    return [] unless ldap.bind

    groups = []
    filter = Net::LDAP::Filter.eq('objectClass', 'groupOfUniqueNames')
    ldap.search(base: BASE_DN, filter: filter) do |entry|
      members = entry.respond_to?(:uniqueMember) ? entry.uniqueMember : []
      groups << {
        dn: entry.dn,
        cn: entry.respond_to?(:cn) ? entry.cn.first : 'N/A',
        members: members.map { |m| m.match(/uid=([^,]+)/)[1] rescue m }
      }
    end
    groups
  end

  def fetch_user_details(uid)
    ldap = ldap_admin
    return nil unless ldap.bind

    filter = Net::LDAP::Filter.eq('uid', uid)
    result = nil
    ldap.search(base: BASE_DN, filter: filter) do |entry|
      attrs = {}
      entry.each do |attribute, values|
        next if attribute == :dn
        attrs[attribute.to_s] = values.map(&:to_s)
      end
      result = { dn: entry.dn, attributes: attrs }
    end
    result
  end

  def logged_in?
    session[:user] != nil
  end

  def current_user
    session[:user]
  end

  def h(text)
    Rack::Utils.escape_html(text.to_s)
  end
end

# --- Routes ---

# Page d'accueil : annuaire des utilisateurs
get '/' do
  @users = fetch_all_users
  @groups = fetch_groups
  erb :index
end

# Formulaire de connexion
get '/login' do
  erb :login
end

# Authentification LDAP
post '/login' do
  uid = params[:uid].to_s.strip
  password = params[:password].to_s.strip

  if uid.empty? || password.empty?
    @error = 'Veuillez remplir tous les champs.'
    return erb(:login)
  end

  ldap = ldap_user(uid, password)
  if ldap.bind
    session[:user] = uid
    @success = "Authentification reussie en tant que #{uid} !"

    # Récupérer les infos de l'utilisateur connecté
    filter = Net::LDAP::Filter.eq('uid', uid)
    ldap.search(base: BASE_DN, filter: filter) do |entry|
      session[:user_cn] = entry.cn.first if entry.respond_to?(:cn)
      session[:user_mail] = entry.mail.first if entry.respond_to?(:mail)
    end

    redirect '/'
  else
    @error = "Echec de l'authentification : #{ldap.get_operation_result.message}"
    erb :login
  end
end

# Déconnexion
get '/logout' do
  session.clear
  redirect '/'
end

# Détail d'un utilisateur
get '/user/:uid' do
  @user = fetch_user_details(params[:uid])
  @groups = fetch_groups
  @uid = params[:uid]
  erb :user_detail
end

# Recherche LDAP
get '/search' do
  @query = params[:q].to_s.strip
  @results = []

  unless @query.empty?
    ldap = ldap_admin
    if ldap.bind
      filter = Net::LDAP::Filter.contains('cn', @query) |
               Net::LDAP::Filter.contains('mail', @query) |
               Net::LDAP::Filter.eq('uid', @query)
      ldap.search(base: BASE_DN, filter: filter) do |entry|
        @results << {
          dn: entry.dn,
          uid: entry.respond_to?(:uid) ? entry.uid.first : 'N/A',
          cn: entry.respond_to?(:cn) ? entry.cn.first : 'N/A',
          mail: entry.respond_to?(:mail) ? entry.mail.first : 'N/A'
        }
      end
    end
  end

  erb :search
end
