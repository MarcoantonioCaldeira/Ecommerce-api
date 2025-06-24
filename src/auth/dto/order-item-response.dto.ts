import { Exclude, Type } from 'class-transformer';
import { ProductResponseDto } from './product-response.dto';

export class OrderItemResponseDto {
  @Exclude() id: number;
  @Exclude() orderId: number;
  @Exclude() productId: number;
  
  quantity: number;
  price: number;

  @Type(() => ProductResponseDto)
  product: ProductResponseDto;
}