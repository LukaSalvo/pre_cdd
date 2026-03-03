#!/usr/bin/env ruby
# Script PoC : Raccordement au LDAP de l'Université de Lorraine
# Étape 2 du projet : Connexion sécurisée LDAPS et recherche dans l'annuaire

require 'net/ldap'
require 'dotenv/load'

# --- Configuration ---

LDAP_SERVERS = [
  'montet-dc1.ad.univ-lorraine.fr',
  'montet-dc2.ad.univ-lorraine.fr'
].freeze

LDAP_PORT = 636

# Base DN plus large pour trouver aussi bien les personnels que les étudiants
BASE_DN_USERS = 'OU=_Utilisateurs,OU=UL,DC=ad,DC=univ-lorraine,DC=fr'
BASE_DN_STAFF = 'OU=Personnels,OU=_Utilisateurs,OU=UL,DC=ad,DC=univ-lorraine,DC=fr'

# Groupes d'intérêt pour le rattachement structurel
GROUPS = {
  'GGA_STP_FHB--' => 'IUT Nancy-Charlemagne (IUTNC)',
  'GGA_STP_FHBAB' => 'Département Informatique'
}.freeze

# --- Vérification des identifiants ---

username = ENV['LDAP_USERNAME']
password = ENV['LDAP_PASSWORD']

if username.nil? || username.empty? || password.nil? || password.empty?
  puts "Erreur: Les variables d'environnement LDAP_USERNAME et LDAP_PASSWORD doivent etre definies."
  puts
  puts 'Usage (methode 1 - fichier .env) :'
  puts '  cp .env.example .env'
  puts '  # editer .env avec vos identifiants'
  puts '  ruby ldap_univ_poc.rb [login_a_chercher]'
  puts
  puts 'Usage (methode 2 - variables inline) :'
  puts "  LDAP_USERNAME='votre_login' LDAP_PASSWORD='votre_mdp' ruby ldap_univ_poc.rb [login_a_chercher]"
  exit 1
end

# --- Fonctions utilitaires ---

def separator
  puts '-' * 60
end

def afficher_rattachement(groups)
  rattachements = []
  groups.each do |group_dn|
    GROUPS.each do |pattern, label|
      rattachements << label if group_dn.include?(pattern)
    end
  end
  rattachements
end

# --- Connexion avec failover ---

def connect_ldap(username, password)
  LDAP_SERVERS.each do |server|
    puts "Tentative de connexion a #{server}:#{LDAP_PORT} (LDAPS)..."

    ldap = Net::LDAP.new(
      host: server,
      port: LDAP_PORT,
      encryption: {
        method: :simple_tls,
        tls_options: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
      },
      auth: {
        method: :simple,
        username: "#{username}@etu.univ-lorraine.fr",
        password: password
      }
    )

    if ldap.bind
      puts "✓ Connecte a #{server} en tant que #{username}"
      return ldap
    else
      puts "✗ Echec sur #{server}: #{ldap.get_operation_result.message}"
    end
  end

  nil
end

# --- Recherche d'un utilisateur ---

def rechercher_utilisateur(ldap, search_term, base_dn)
  # On cherche par sAMAccountName (login) ou par cn (nom)
  filter_sam = Net::LDAP::Filter.eq('sAMAccountName', search_term)
  filter_cn  = Net::LDAP::Filter.contains('cn', search_term)
  filter     = filter_sam | filter_cn

  puts "Recherche de '#{search_term}' dans #{base_dn}..."
  separator

  count = 0
  ldap.search(base: base_dn, filter: filter) do |entry|
    count += 1
    puts
    puts "  DN:    #{entry.dn}"
    puts "  Nom:   #{entry.cn.first}" if entry.respond_to?(:cn) && entry.cn
    puts "  Login: #{entry.sAMAccountName.first}" if entry.respond_to?(:sAMAccountName) && entry.sAMAccountName
    puts "  Email: #{entry.mail.first}" if entry.respond_to?(:mail) && entry.mail
    puts "  Tel:   #{entry.telephoneNumber.first}" if entry.respond_to?(:telephoneNumber) && entry.telephoneNumber

    # Affichage du rattachement structurel
    if entry.respond_to?(:memberOf) && entry.memberOf
      rattachements = afficher_rattachement(entry.memberOf)

      unless rattachements.empty?
        puts '  Rattachement:'
        rattachements.each { |r| puts "    → #{r}" }
      end

      # Affichage des groupes (optionnel, pour debug)
      if ARGV.include?('--verbose') || ARGV.include?('-v')
        puts '  Tous les groupes:'
        entry.memberOf.each { |g| puts "    - #{g}" }
      end
    end

    separator
  end

  if count.zero?
    puts "Aucun utilisateur trouve pour '#{search_term}'."
  else
    puts "\n#{count} utilisateur(s) trouve(s)."
  end

  # Vérification du résultat de l'opération
  result = ldap.get_operation_result
  if result.code != 0
    puts "Avertissement: #{result.message} (code #{result.code})"
  end

  count
end

# --- Programme principal ---

puts '=' * 60
puts '  PoC LDAP - Universite de Lorraine'
puts '=' * 60
puts

# Connexion
ldap = connect_ldap(username, password)

unless ldap
  puts "\nImpossible de se connecter a aucun serveur LDAP."
  exit 1
end

puts
separator

# Terme de recherche : argument CLI ou login de l'utilisateur connecté
search_term = (ARGV.reject { |a| a.start_with?('-') }.first || username).strip

# Recherche dans le DN large (_Utilisateurs) d'abord
puts "\n=== Recherche dans l'annuaire des utilisateurs ==="
count = rechercher_utilisateur(ldap, search_term, BASE_DN_USERS)

# Si rien trouvé dans le DN large, essayer le DN personnel spécifiquement
if count.zero? && BASE_DN_USERS != BASE_DN_STAFF
  puts "\n=== Recherche dans l'annuaire des personnels ==="
  rechercher_utilisateur(ldap, search_term, BASE_DN_STAFF)
end

puts
puts '✓ Script termine.'
