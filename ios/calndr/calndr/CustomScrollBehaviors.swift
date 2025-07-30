import SwiftUI

// MARK: - Custom Horizontal Paging Behavior

struct CustomHorizontalPagingBehavior: ScrollTargetBehavior {
    enum Direction {
        case left, right, none
    }

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let scrollViewWidth = context.containerSize.width
        let contentWidth = context.contentSize.width

        // If the content width is less than or equal to the ScrollView width, align to the leftmost position
        guard contentWidth > scrollViewWidth else {
            target.rect.origin.x = 0
            return
        }

        let originalOffset = context.originalTarget.rect.minX
        let targetOffset = target.rect.minX

        // Determine the scroll direction by comparing the original offset with the target offset
        let direction: Direction = targetOffset > originalOffset ? .left : (targetOffset < originalOffset ? .right : .none)
        guard direction != .none else {
            target.rect.origin.x = originalOffset
            return
        }

        let thresholdRatio: CGFloat = 1 / 3

        // Calculate the remaining content width based on the scroll direction and determine the drag threshold
        let remaining: CGFloat = direction == .left
            ? (contentWidth - context.originalTarget.rect.maxX)
            : (context.originalTarget.rect.minX)

        let threshold = remaining <= scrollViewWidth ? remaining * thresholdRatio : scrollViewWidth * thresholdRatio

        let dragDistance = originalOffset - targetOffset
        var destination: CGFloat = originalOffset

        if abs(dragDistance) > threshold {
            // If the drag distance exceeds the threshold, adjust the target to the previous or next page
            destination = dragDistance > 0 ? originalOffset - scrollViewWidth : originalOffset + scrollViewWidth
        } else {
            // If the drag distance is within the threshold, align based on the scroll direction
            if direction == .right {
                // Scroll right (page left), round up
                destination = ceil(originalOffset / scrollViewWidth) * scrollViewWidth
            } else {
                // Scroll left (page right), round down
                destination = floor(originalOffset / scrollViewWidth) * scrollViewWidth
            }
        }

        // Boundary handling: Ensure the destination is within valid bounds and aligns with pages
        let maxOffset = contentWidth - scrollViewWidth
        let boundedDestination = min(max(destination, 0), maxOffset)

        if boundedDestination >= maxOffset * 0.95 {
            // If near the end, snap to the last possible position
            destination = maxOffset
        } else if boundedDestination <= scrollViewWidth * 0.05 {
            // If near the start, snap to the beginning
            destination = 0
        } else {
            if direction == .right {
                // For right-to-left scrolling, calculate from the right end
                let offsetFromRight = maxOffset - boundedDestination
                let pageFromRight = round(offsetFromRight / scrollViewWidth)
                destination = maxOffset - (pageFromRight * scrollViewWidth)
            } else {
                // For left-to-right scrolling, keep original behavior
                let pageNumber = round(boundedDestination / scrollViewWidth)
                destination = min(pageNumber * scrollViewWidth, maxOffset)
            }
        }

        target.rect.origin.x = destination
    }
}

// MARK: - Custom Vertical Paging Behavior

struct CustomVerticalPagingBehavior: ScrollTargetBehavior {
    enum Direction {
        case up, down, none
    }

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let scrollViewHeight = context.containerSize.height
        let contentHeight = context.contentSize.height

        // If the content height is less than or equal to the ScrollView height, align to the topmost position
        guard contentHeight > scrollViewHeight else {
            target.rect.origin.y = 0
            return
        }

        let originalOffset = context.originalTarget.rect.minY
        let targetOffset = target.rect.minY

        // Determine the scroll direction by comparing the original offset with the target offset
        let direction: Direction = targetOffset > originalOffset ? .up : (targetOffset < originalOffset ? .down : .none)
        guard direction != .none else {
            target.rect.origin.y = originalOffset
            return
        }

        let thresholdRatio: CGFloat = 1 / 3

        // Calculate the remaining content height based on the scroll direction and determine the drag threshold
        let remaining: CGFloat = direction == .up
            ? (contentHeight - context.originalTarget.rect.maxY)
            : (context.originalTarget.rect.minY)

        let threshold = remaining <= scrollViewHeight ? remaining * thresholdRatio : scrollViewHeight * thresholdRatio

        let dragDistance = originalOffset - targetOffset
        var destination: CGFloat = originalOffset

        if abs(dragDistance) > threshold {
            // If the drag distance exceeds the threshold, adjust the target to the previous or next page
            destination = dragDistance > 0 ? originalOffset - scrollViewHeight : originalOffset + scrollViewHeight
        } else {
            // If the drag distance is within the threshold, align based on the scroll direction
            if direction == .down {
                // Scroll down (page up), round up
                destination = ceil(originalOffset / scrollViewHeight) * scrollViewHeight
            } else {
                // Scroll up (page down), round down
                destination = floor(originalOffset / scrollViewHeight) * scrollViewHeight
            }
        }

        // Boundary handling: Ensure the destination is within valid bounds and aligns with pages
        let maxOffset = contentHeight - scrollViewHeight
        let boundedDestination = min(max(destination, 0), maxOffset)

        if boundedDestination >= maxOffset * 0.95 {
            // If near the end, snap to the last possible position
            destination = maxOffset
        } else if boundedDestination <= scrollViewHeight * 0.05 {
            // If near the start, snap to the beginning
            destination = 0
        } else {
            if direction == .down {
                // For down scrolling, calculate from the bottom end
                let offsetFromBottom = maxOffset - boundedDestination
                let pageFromBottom = round(offsetFromBottom / scrollViewHeight)
                destination = maxOffset - (pageFromBottom * scrollViewHeight)
            } else {
                // For up scrolling, keep original behavior
                let pageNumber = round(boundedDestination / scrollViewHeight)
                destination = min(pageNumber * scrollViewHeight, maxOffset)
            }
        }

        target.rect.origin.y = destination
    }
}

// MARK: - Custom List Paging Behavior (Smooth vertical scrolling for lists)

struct CustomListPagingBehavior: ScrollTargetBehavior {
    let itemHeight: CGFloat
    
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let scrollViewHeight = context.containerSize.height
        let contentHeight = context.contentSize.height
        
        // If content fits within the scroll view, align to top
        guard contentHeight > scrollViewHeight else {
            target.rect.origin.y = 0
            return
        }
        
        let targetOffset = target.rect.minY
        
        // Calculate which item should be at the top
        let targetItemIndex = round(targetOffset / itemHeight)
        let snappedOffset = targetItemIndex * itemHeight
        
        // Ensure we don't scroll past the content
        let maxOffset = contentHeight - scrollViewHeight
        target.rect.origin.y = min(max(snappedOffset, 0), maxOffset)
    }
}