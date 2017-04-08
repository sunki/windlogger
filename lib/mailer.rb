require 'net/smtp'

class Mailer

  MARKER = '%%MSG_PART%%'

  class SmtpMaxAttemptsReached < StandardError; end

  def initialize(body, attach_path = nil)
    @attempts = 0
    @body = body
    @attach_path = attach_path
  end

  def mail
    @msg = <<-MSG
From: #{CFG['email']}
To: #{CFG['email']}
Subject: windlogger daily data
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=#{MARKER}\n
--#{MARKER}
Content-Type: text/plain; charset=ISO-8859-1\n
#{@body}
    MSG

    if @attach_path
      attach = File.binread(@attach_path)
      attach = [attach].pack('m')
      @msg << <<-MSG
--#{MARKER}
Content-Type: application/zip; name="#{ZIP_NAME}"
Content-Transfer-Encoding:base64
Content-Disposition: attachment; filename="#{ZIP_NAME}"\n
#{attach}
      MSG
    end

    @msg << "\n--#{MARKER}--"
    process
  end

  def process
    begin
      Timeout.timeout(CFG['smtp_timeout']) do
        net = Net::SMTP.new(CFG['server'], CFG['port'])
        net.enable_ssl
        net.start('localhost.localdomain', CFG['email'], CFG['pass']) do |smtp|
          LOG.info "sending mail (attempt: #{@attempts})"
          smtp.send_message(@msg, CFG['email'], CFG['email'])
        end
      end
    rescue => err
      LOG.error "#{err.message}\n#{err.backtrace.join("\n")}"
      @attempts += 1
      raise SmtpMaxAttemptsReached if @attempts >= CFG['smtp_attempts']
      sleep(CFG['smtp_attempts_delay'])
      process
    end
  end
end
