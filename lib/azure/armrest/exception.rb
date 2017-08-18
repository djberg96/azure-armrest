module Azure
  module Armrest
    class Exception < StandardError
      attr_accessor :cause
      attr_writer :message

      # Create a new Armrest::Exception object. The +message+ should be an
      # error string, while +cause_exception+ is typically set on the
      # raw Faraday exception.
      #
      # You will not typically use this object directly.
      #
      def initialize(message = nil, cause_exception = nil)
        @message = message
        @cause = cause_exception
      end

      # The stringified version (message) of the exception.
      #
      def to_s
        if cause
          "#{message} (cause: #{cause})"
        else
          message
        end
      end

      # The error message or, if the message is not set, the name of the
      # exception class.
      #
      def message
        @message || self.class.name
      end
    end

    class ApiException < Exception
      attr_accessor :code

      # Create a new ApiException class. The +code+ is the error code.
      #
      # This class serves as the parent
      def initialize(code, message, cause_exception)
        @code = code
        super(message, cause_exception)
      end

      # A stringified version of the error. If self is a plain ApiException,
      # then the cause is included to aid in debugging.
      #
      def to_s
        "[#{code}] #{super}"
      end
    end

    # Rewrapped HTTP errors
    class BadGatewayException < ApiException; end
    class BadRequestException < ApiException; end
    class BandwidthLimitExceededException < ApiException; end
    class BlockedByWindowsParentalControlsException < ApiException; end
    class ConflictException < ApiException; end
    class ExpectationFailedException < ApiException; end
    class FailedDependencyException < ApiException; end
    class ForbiddenException < ApiException; end
    class GatewayTimeoutException < ApiException; end
    class GoneException < ApiException; end
    class HTTPVersionNotSupportedException < ApiException; end
    class ImATeapotException < ApiException; end
    class InsufficientStorageException < ApiException; end
    class InternalServerErrorException < ApiException; end
    class LengthRequiredException < ApiException; end
    class LockedException < ApiException; end
    class LoopDetectedException < ApiException; end
    class MethodNotAllowedException < ApiException; end
    class NetworkAuthenticationRequiredException < ApiException; end
    class NotAcceptableException < ApiException; end
    class NotExtendedException < ApiException; end
    class NotFoundException < ApiException; end
    class NotImplementedException < ApiException; end
    class PayloadTooLargeException < ApiException; end
    class PaymentRequiredException < ApiException; end
    class PreconditionFailedException < ApiException; end
    class PreconditionRequiredException < ApiException; end
    class ProxyAuthenticationRequiredException < ApiException; end
    class RangeNotSatisfiableException < ApiException; end
    class RequestHeaderFieldsTooLargeException < ApiException; end
    class RequestTimeoutException < ApiException; end
    class RetryWithException < ApiException; end
    class ServiceUnavailableException < ApiException; end
    class TooManyConnectionsFromThisIPException < ApiException; end
    class TooManyRequestsException < ApiException; end
    class URITooLongException < ApiException; end
    class UnauthorizedException < ApiException; end
    class UnorderedCollectionException < ApiException; end
    class UnprocessableEntityException < ApiException; end
    class UnsupportedMediaTypeException < ApiException; end
    class UpgradeRequiredException < ApiException; end
    class VariantAlsoNegotiatesException < ApiException; end

    # Custom errors or other wrapped exceptions
    class ResourceNotFoundException < ApiException; end
    class TimeoutException < RequestTimeoutException; end
    class OpenTimeoutException < TimeoutException; end
    class ReadTimeoutException < TimeoutException; end

    # Map HTTP error codes to our exception classes
    EXCEPTION_MAP = {
      400 => BadRequestException,
      401 => UnauthorizedException,
      402 => PaymentRequiredException,
      403 => ForbiddenException,
      404 => NotFoundException,
      405 => MethodNotAllowedException,
      406 => NotAcceptableException,
      407 => ProxyAuthenticationRequiredException,
      408 => RequestTimeoutException,
      409 => ConflictException,
      410 => GoneException,
      411 => LengthRequiredException,
      412 => PreconditionFailedException,
      413 => PayloadTooLargeException,
      414 => URITooLongException,
      415 => UnsupportedMediaTypeException,
      416 => RangeNotSatisfiableException,
      417 => ExpectationFailedException,
      418 => ImATeapotException,
      421 => TooManyConnectionsFromThisIPException,
      422 => UnprocessableEntityException,
      423 => LockedException,
      424 => FailedDependencyException,
      425 => UnorderedCollectionException,
      426 => UpgradeRequiredException,
      428 => PreconditionRequiredException,
      429 => TooManyRequestsException,
      431 => RequestHeaderFieldsTooLargeException,
      449 => RetryWithException,
      450 => BlockedByWindowsParentalControlsException,
      500 => InternalServerErrorException,
      501 => NotImplementedException,
      502 => BadGatewayException,
      503 => ServiceUnavailableException,
      504 => GatewayTimeoutException,
      505 => HTTPVersionNotSupportedException,
      506 => VariantAlsoNegotiatesException,
      507 => InsufficientStorageException,
      508 => LoopDetectedException,
      509 => BandwidthLimitExceededException,
      510 => NotExtendedException,
      511 => NetworkAuthenticationRequiredException
    }.freeze
  end
end
