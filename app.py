import os
import json
from flask import Flask, jsonify
import sqlalchemy
from sqlalchemy import create_engine, text
import pymysql
import psycopg2

from datetime import datetime

app = Flask(__name__)

# Database configuration from environment variables
DB_TYPE = os.getenv('DATABASE_TYPE', 'rds')
DB_ENGINE = os.getenv('DATABASE_ENGINE', 'mysql')
DB_HOST = os.getenv('DATABASE_HOST', 'localhost')
DB_PORT = os.getenv('DATABASE_PORT', '3306')
DB_NAME = os.getenv('DATABASE_NAME', 'testdb')
DB_USER = os.getenv('DATABASE_USERNAME', 'admin')
DB_PASSWORD = os.getenv('DATABASE_PASSWORD', 'password')
APP_PORT = int(os.getenv('SERVER_PORT', '8080'))


def get_database_url():
    """Construct database URL based on engine type"""
    # Check if host already includes port
    if ':' in DB_HOST:
        host_part = DB_HOST
    else:
        host_part = f"{DB_HOST}:{DB_PORT}"

    if DB_ENGINE == 'mysql':
        return f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{host_part}/{DB_NAME}"
    elif DB_ENGINE == 'postgres':
        return f"postgresql://{DB_USER}:{DB_PASSWORD}@{host_part}/{DB_NAME}"
    else:
        raise ValueError(f"Unsupported database engine: {DB_ENGINE}")


def test_database_connection():
    """Test database connection and return connection status"""
    if DB_TYPE == 'none' or not DB_HOST:
        return {
            'status': 'skipped',
            'message': 'No database configuration provided',
            'connected': False
        }

    try:
        # Create database engine
        database_url = get_database_url()
        engine = create_engine(database_url, connect_args={'connect_timeout': 5})

        # Test connection with a simple query
        with engine.connect() as connection:
            if DB_ENGINE == 'mysql':
                result = connection.execute(text("SELECT VERSION() as version"))
            elif DB_ENGINE == 'postgres':
                result = connection.execute(text("SELECT version() as version"))
            else:
                result = connection.execute(text("SELECT 1 as test"))

            row = result.fetchone()
            db_version = row[0] if row else "Unknown"

            return {
                'status': 'success',
                'message': 'Database connection successful',
                'connected': True,
                'engine': DB_ENGINE,
                'host': DB_HOST,
                'port': DB_PORT,
                'database': DB_NAME,
                'version': db_version
            }

    except Exception as e:
        return {
            'status': 'error',
            'message': f'Database connection failed: {str(e)}',
            'connected': False,
            'engine': DB_ENGINE,
            'host': DB_HOST,
            'port': DB_PORT,
            'database': DB_NAME,
            'error': str(e)
        }


@app.route('/health', methods=['GET'])
def health_check():
    """Simple health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'message': 'Application is running',
        'timestamp': datetime.now().isoformat()
    }), 200


@app.route('/db-test', methods=['GET'])
def database_test():
    """Test database connection endpoint"""
    db_result = test_database_connection()

    # Return 200 for successful connection, 503 for failed connection
    status_code = 200 if db_result['connected'] else 503

    return jsonify({
        'application': 'ECS RDS Test App',
        'database_test': db_result,
        'environment': {
            'aws_region': os.getenv('AWS_REGION', 'unknown'),
            'database_type': DB_TYPE,
            'database_engine': DB_ENGINE
        }
    }), status_code


@app.route('/db-query', methods=['GET'])
def database_query():
    """Execute a simple database query"""
    if DB_TYPE == 'none' or not DB_HOST:
        return jsonify({
            'status': 'skipped',
            'message': 'No database configuration provided'
        }), 200

    try:
        database_url = get_database_url()
        engine = create_engine(database_url, connect_args={'connect_timeout': 5})

        with engine.connect() as connection:
            # Create a simple test table and insert data
            if DB_ENGINE == 'mysql':
                connection.execute(text("""
                                        CREATE TABLE IF NOT EXISTS health_check
                                        (
                                            id
                                            INT
                                            AUTO_INCREMENT
                                            PRIMARY
                                            KEY,
                                            timestamp
                                            DATETIME
                                            DEFAULT
                                            CURRENT_TIMESTAMP,
                                            status
                                            VARCHAR
                                        (
                                            50
                                        )
                                            )
                                        """))
                connection.execute(text("""
                                        INSERT INTO health_check (status)
                                        VALUES ('healthy')
                                        """))
                result = connection.execute(text("""
                                                 SELECT id, timestamp, status
                                                 FROM health_check
                                                 ORDER BY id DESC LIMIT 5
                                                 """))
            elif DB_ENGINE == 'postgres':
                connection.execute(text("""
                                        CREATE TABLE IF NOT EXISTS health_check
                                        (
                                            id
                                            SERIAL
                                            PRIMARY
                                            KEY,
                                            timestamp
                                            TIMESTAMP
                                            DEFAULT
                                            CURRENT_TIMESTAMP,
                                            status
                                            VARCHAR
                                        (
                                            50
                                        )
                                            )
                                        """))
                connection.execute(text("""
                                        INSERT INTO health_check (status)
                                        VALUES ('healthy')
                                        """))
                result = connection.execute(text("""
                                                 SELECT id, timestamp, status
                                                 FROM health_check
                                                 ORDER BY id DESC LIMIT 5
                                                 """))

            connection.commit()
            rows = result.fetchall()

            return jsonify({
                'status': 'success',
                'message': 'Database query executed successfully',
                'data': [{'id': row[0], 'timestamp': str(row[1]), 'status': row[2]} for row in rows],
                'record_count': len(rows)
            }), 200

    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Database query failed: {str(e)}',
            'error': str(e)
        }), 500


@app.route('/info', methods=['GET'])
def app_info():
    """Application information endpoint"""
    return jsonify({
        'application': 'ECS RDS Test App',
        'version': '1.0.0',
        'environment_variables': {
            'AWS_REGION': os.getenv('AWS_REGION', 'not-set'),
            'DATABASE_TYPE': DB_TYPE,
            'DATABASE_ENGINE': DB_ENGINE,
            'DATABASE_HOST': DB_HOST,
            'DATABASE_PORT': DB_PORT,
            'DATABASE_NAME': DB_NAME,
            'SERVER_PORT': APP_PORT
        },
        'endpoints': {
            '/health': 'Health check endpoint',
            '/db-test': 'Test database connection',
            '/db-query': 'Execute simple database query',
            '/info': 'Application information'
        }
    }), 200


@app.route('/', methods=['GET'])
def root():
    """Root endpoint"""
    return jsonify({
        'message': 'ECS RDS Test Application',
        'status': 'running',
        'endpoints': ['/health', '/db-test', '/db-query', '/info']
    }), 200


if __name__ == '__main__':
    print(f"Starting ECS RDS Test App on port {APP_PORT}")
    print(f"Database Type: {DB_TYPE}")
    print(f"Database Engine: {DB_ENGINE}")
    print(f"Database Host: {DB_HOST}")

    app.run(host='0.0.0.0', port=APP_PORT, debug=False)