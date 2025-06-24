import { Exclude, Expose, Type } from 'class-transformer';
import { OrderItemResponseDto } from './order-item-response.dto';
import { UserResponseDto } from './user-response.dto'; 

export class OrderResponseDto {
  id: number;
  status: string;
  @Expose({ name: 'totalPrice' })
  calculatedTotalPrice: number;
  @Type(() => UserResponseDto)
  user: UserResponseDto;
  @Type(() => OrderItemResponseDto)
  items: OrderItemResponseDto[];
  @Exclude() userId: number;
}