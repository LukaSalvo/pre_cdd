#!/usr/bin/env ruby
# Application web Sinatra de raccordement au LDAP de l'Université de Lorraine
# Étape 2 du projet : Connexion sécurisée LDAPS via une interface web

require 'sinatra'
require 'net/ldap'
require 'dotenv'
Dotenv.load(File.join(__dir__, '..', '.env'))

# --- Configuration ---

LDAP_HOST = 'montet-dc1.ad.univ-lorraine.fr'
LDAP_PORT = 636
BASE_DN   = 'OU=_Utilisateurs,OU=UL,DC=ad,DC=univ-lorraine,DC=fr'
ADMIN_USER = ENV['LDAP_USERNAME'] || ENV['LDAP_DN']
ADMIN_PWD  = ENV['LDAP_PASSWORD'] || ENV['LDAP_PASS']

# Build full UPN — avoid double-appending the domain suffix
ADMIN_UPN = ADMIN_USER&.include?('@') ? ADMIN_USER : "#{ADMIN_USER}@etu.univ-lorraine.fr"

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
      connect_timeout: 10,
      encryption: {
        method: :simple_tls,
        tls_options: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
      },
      auth: {
        method: :simple,
        username: ADMIN_UPN,
        password: ADMIN_PWD
      }
    )
  end

  def ldap_user(uid, password)
    Net::LDAP.new(
      host: LDAP_HOST,
      port: LDAP_PORT,
      connect_timeout: 10,
      encryption: {
        method: :simple_tls,
        tls_options: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
      },
      auth: {
        method: :simple,
        username: "#{uid}@etu.univ-lorraine.fr",
        password: password
      }
    )
  end

  def fetch_all_users
    ldap = ldap_admin
    return [] unless ldap.bind

    users = []
    filter = Net::LDAP::Filter.eq('objectClass', 'user')
    ldap.search(base: BASE_DN, filter: filter, size: 50) do |entry|
      sam = entry.respond_to?(:sAMAccountName) ? entry.sAMAccountName.first : nil
      next unless sam
      users << {
        dn: entry.dn,
        uid: sam,
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
    filter = Net::LDAP::Filter.eq('objectClass', 'group')
    ldap.search(base: BASE_DN, filter: filter, size: 50) do |entry|
      members = entry.respond_to?(:member) ? entry.member : []
      groups << {
        dn: entry.dn,
        cn: entry.respond_to?(:cn) ? entry.cn.first : 'N/A',
        members: members.map { |m| m.match(/CN=([^,]+)/i)[1] rescue m }
      }
    end
    groups
  end

  def fetch_user_details(uid)
    ldap = ldap_admin
    return nil unless ldap.bind

    filter = Net::LDAP::Filter.eq('sAMAccountName', uid)
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

# --- Gestion d'erreur globale ---

error Net::LDAP::Error do
  @error = "Impossible de joindre le serveur LDAP (#{LDAP_HOST}:#{LDAP_PORT}). " \
           "Verifiez votre connexion reseau ou reessayez plus tard."
  @users = []
  @groups = []
  erb :index
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
    filter = Net::LDAP::Filter.eq('sAMAccountName', uid)
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
               Net::LDAP::Filter.eq('sAMAccountName', @query)
      ldap.search(base: BASE_DN, filter: filter, size: 50) do |entry|
        @results << {
          dn: entry.dn,
          uid: entry.respond_to?(:sAMAccountName) ? entry.sAMAccountName.first : 'N/A',
          cn: entry.respond_to?(:cn) ? entry.cn.first : 'N/A',
          mail: entry.respond_to?(:mail) ? entry.mail.first : 'N/A'
        }
      end
    end
  end

  erb :search
end
