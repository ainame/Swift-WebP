import Foundation

protocol InternalRawRepresentable {
    associatedtype RawValue
    
    init?(rawValue: Self.RawValue)
    
    var rawValue: Self.RawValue { get }
}
