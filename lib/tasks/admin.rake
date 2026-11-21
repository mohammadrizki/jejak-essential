namespace :admin do
  desc "Create an administrator account"
  task create: :environment do
    require "io/console"

    print "Nama lengkap: "
    full_name = STDIN.gets.chomp

    print "Email: "
    email = STDIN.gets.chomp

    password = IO::console.getpass("Password: ")
    password_confirmation = IO::console.getpass("Konfirmasi password: ")

    abort "Password tidak cocok." unless password == password_confirmation

    User.transaction do
      admin_role = Role.find_or_create_by!(code: "admin") do |role|
        role.name = "Admin"
      end

      user = User.create!(
        full_name: full_name,
        email: email,
        password: password,
        password_confirmation: password_confirmation,
        confirmed_at: Time.current,
        active_role: admin_role
      )

      user.roles << admin_role

      puts "Admin berhasil dibuat: #{user.email}"
    end
  rescue ActiveRecord::RecordInvalid => e
    abort "Gagal membuat admin: #{e.record.errors.full_messages.join(', ')}"
  end
end
