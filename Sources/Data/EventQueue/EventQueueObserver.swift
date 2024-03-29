// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

public protocol EventQueueObserver: AnyObject {
    /// This delegate method is fired when an event is enqueued, including the name and attributes of the Event.
    func eventQueue(_ eventQueue: EventQueue, didAddEvent info: EventInfo)
    
    /// This delegate method is fired when an event is enqueued, providing the fully transformed event, including event ID, captured device context, and more.
    func eventQueue(_ eventQueue: EventQueue, didEnqueueEventDetails details: Event)
}

public extension EventQueueObserver {
    func eventQueue(_ eventQueue: EventQueue, didEnqueueEventDetails details: Event) {
        // this event is optional.
    }
}
