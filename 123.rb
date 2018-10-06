require 'net/smtp'
list_rds = []
exception_rds = []
mailRDS_Instance = []

if File.exist? 'add_rdslist.rb'
  File.foreach( 'add_rdslist.rb' ) do |line|
      list_rds.push line
  end
end

if File.exist? 'rds_exception.rb'
  File.foreach( 'rds_exception.rb' ) do |line2|
      exception_rds.push line2
  end
end

def cloudwatch(ss)
	open("#{ss}.cfg", 'a') { |f|
	f << "define host{\n"
	f << "use                            RDS\n"
	f << "alias                          #{ss}\n"
	f << "host_name                      RDS_#{ss}\n"
	f << "address                        "+ss.to_s+".cjtqukhroz3o.ap-southeast-2.rds.amazonaws.com\n"
	f << "}\n"
	f << " \n "
	}
end

def cpu_utilization(ss)
	open("#{ss}.cfg", 'a') { |f|
	f << "define service {\n"
	f << "service_description                            RDS.CPUUtilization\n"
	f << "check_command                          check_cloudwatch.py!RDS!DBInstanceIdentifier=#{ss}!CPUUtilization!30!20!Average\n"
	f << "host_name                      RDS_#{ss}\n"
	f << "use                        rds-service\n"
	f << "}\n"
	f << " \n "
	}
end

def db_connections(ss)
	open("#{ss}.cfg", 'a') { |f|
	f << "define service {\n"
	f << "service_description                            RDS.DatabaseConnections\n"
	f << "check_command                          check_cloudwatch.py!RDS!DBInstanceIdentifier=#{ss}!DatabaseConnections!3000!2500!Average\n"
	f << "host_name                      RDS_#{ss}\n"
	f << "use                        rds-service\n"
	f << "}\n"
	f << " \n "
	}
end

def write_IOPS(ss)
	open("#{ss}.cfg", 'a') { |f|
	f << "define service {\n"
	f << "service_description                            RDS.WriteIOPS\n"
	f << "check_command                          check_cloudwatch.py!RDS!DBInstanceIdentifier=#{ss}!WriteIOPS!600!500!Average\n"
	f << "host_name                      RDS_#{ss}\n"
	f << "use                        rds-WriteIOPS\n"
	f << "}\n"
	f << " \n "
	}
end

def write_latency(ss)
	open("#{ss}.cfg", 'a') { |f|
	f << "define service {\n"
	f << "service_description                            RDS.WriteLatency\n"
	f << "check_command                          check_cloudwatch.py!RDS!DBInstanceIdentifier=#{ss}!WriteLatency!30!20!Average\n"
	f << "host_name                      RDS_#{ss}\n"
	f << "use                        rds-service\n"
	f << "}\n"
	f << " \n "
	}
end

def rds_exception(ss)
	open('rds_exception.rb', 'a') { |f|
	f << "#{ss}\n"
	}
end

def replica_lag(ss)
	open("#{ss}.cfg", 'a') { |f|
	f << "define service{\n"
	f << "service_description                   RDS.ReplicaLag\n"
	f << "check_command                         check_cloudwatch.py!RDS!DBInstanceIdentifier=#{ss}!ReplicaLag!30!20!Average\n"
	f << "host_name                             RDS_#{ss}\n"
	f << "use                                   rds-replica-service\n"
	f << "}\n"
	f << " \n "
	}
end

rdsList = list_rds - exception_rds
if !rdsList.empty?
	rdsList.each do |new_rds_valu|

	ss = new_rds_valu unless new_rds_valu == '\n'
	ss= ss.strip
	mailRDS_Instance.push(ss)
if !ss.include?("-replica")
	if ss.include?("-slave")
		cloudwatch(ss)
		replica_lag(ss)
		cpu_utilization(ss)
		db_connections(ss)
		write_IOPS(ss)
		write_latency(ss)
		rds_exception(ss)
	else
		cloudwatch(ss)
		cpu_utilization(ss)
		db_connections(ss)
		write_IOPS(ss)
		write_latency(ss)
		rds_exception(ss)
	end
else 
rds_exception(ss)
end
end

message = <<MESSAGE_END
From: RDS <rds@freshdesk.com>
To: NOC <balaji.t@freshdesk.com>
Subject: Freshdesk-US RDS instance added successfully in nagios
Hi Team

#{mailRDS_Instance.join("\n")}

Above RDS Instance is added to nagios monitoring.


Thanks


MESSAGE_END
Net::SMTP.start('localhost') do |smtp|
smtp.send_message message, 'rds@freshdesk.com',
                              'balaji.t@freshdesk.com'
end
exec( "/etc/init.d/nagios restart" )
end